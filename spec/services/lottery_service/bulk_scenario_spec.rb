require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  before do
    stub_const 'LotteryService::DEFAULT_MAX_WINNERS', 1000
    stub_const 'LotteryService::DEFAULT_TOP_N_HOLDERS', 10
    stub_const 'Participant::TICKET_PRICE', 250
    stub_const 'Participant::NO_COOLDOWN_MINIMUM_BALANCE', 30_000
    stub_const 'Participant::BALANCE_WEIGHTS', {
      0      => 0.00,
      250    => 1.00,
      1_000  => 1.10,
      3_000  => 1.15,
      10_000 => 1.20,
      30_000 => 1.25
    }
  end

  before do
    skip if ENV['SKIP_BULK_SPECS']
  end

  let(:service) { described_class.new(balances: balances,
                                      recent_winners: recent_winners,
                                      blacklist: blacklist,
                                      max_winners: LotteryService::DEFAULT_MAX_WINNERS) }

  context 'given holders read from a CSV file with holders' do
    let(:recent_winners) { [] }
    let(:blacklist) {
      csv = CSV.read('spec/fixtures/whales.csv', headers: true)
      csv.map { |holder| holder['address'] }
    }
    let(:balances) {
      csv = CSV.read('spec/fixtures/holders.csv', headers: true)
      csv.map { |holder| [holder['address'], holder['pols_balance'].to_f] }.to_h
    }

    describe '#run' do
      it 'runs and generates an expected number of participants, of winners and intermediate sizes' do
        service.run

        expect(service.all_participants.size).to                       eq(38_191) # total participants, excluding potential whales (stored on whales.csv)
        expect(service.participants.size).to                           eq(18_508) # eligible participants only
        expect(service.send(:top_holders).size).to                     eq(LotteryService::DEFAULT_TOP_N_HOLDERS)
        expect(service.winners.size).to                                eq(LotteryService::DEFAULT_MAX_WINNERS)
      end

      # TODO: refactor to a custom matcher:
      def be_around(value, error: 0.01)
        a_value_between (value - error),
                        (value + error)
      end

      def stats_for(tier_stats, number_of_experiments)
        "#{tier_stats[:percentage].round(1)}% (#{tier_stats[:winners]} number of wins of a total of #{tier_stats[:participants]} participants in all experiments)"
      end

      it 'runs and generates the expected probabilites for some key holders' do
        number_of_experiments = 50
        error = 0.25

        # Run experiments
        experiments = []
        experiments_output = []
        tiers_experiments = {}
        start_at = Time.now.to_f

        puts ""
        number_of_experiments.times do |index|
          timestamp = Time.now.to_f

          service.run
          experiments << service.winners.map(&:address)

          # Collect tier stats to show at the end
          tiers_experiments.deep_merge!(service.stats_by_tier) { |key, v1, v2| v1 + v2 }
          tiers_experiments.each do |tier, stats|
            tiers_experiments[tier][:percentage] = stats[:winners].to_f / stats[:participants] * 100
          end

          # Write output to CSV
          service.winners.each do |winner|
            experiments_output << [index, winner.address, winner.balance, winner.weight, winner.tier, winner.tickets]
          end

          expect(service.winners.size).to eq(LotteryService::DEFAULT_MAX_WINNERS)
          puts "#{service.winners.size} winners for experiment #{index}"

          time_diff = Time.now.to_f - timestamp
          puts " performed experiment number #{index} of #{number_of_experiments} for a bulk scenario [last experiment executed in #{time_diff.round(2)} seconds]" if index % 10 == 0
        end
        puts "Total run time: #{(Time.now.to_f - start_at).round(2)} seconds"

        # Write output to CSV
        CSV.open('experiments_output.csv', 'w') do |csv|
          csv << %w(experiment address balance weight tier tickets)
          csv << experiments_output.each { |row| csv << row }
        end

        # Calulcate probabilities
        occurences = experiments.flatten.count_by { |address| address }
        probabilities_hash = occurences.transform_values { |value| value.to_f / number_of_experiments }
        probabilities_array = probabilities_hash.sort_by { |address, probability| probability }.reverse

        # Print Statistics
        puts ""
        puts "Probabilities for #{number_of_experiments} experiments (#{LotteryService::DEFAULT_MAX_WINNERS} winners on each) over a total of #{balances.count} participants with a ticket price of #{Participant::TICKET_PRICE} POLS:"
        puts " * Top #{LotteryService::DEFAULT_TOP_N_HOLDERS} holders: #{probabilities_array.first[1] * 100 rescue 0}%"
        puts " * <250 POLS: #{stats_for(tiers_experiments[0], number_of_experiments)}"
        puts " * 250+ POLS: #{stats_for(tiers_experiments[250], number_of_experiments)}"
        puts " * 1k+ POLS:  #{stats_for(tiers_experiments[1_000], number_of_experiments)}"
        puts " * 3k+ POLS:  #{stats_for(tiers_experiments[3_000], number_of_experiments)}"
        puts " * 10k+ POLS: #{stats_for(tiers_experiments[10_000], number_of_experiments)}"
        puts " * 30k+ POLS: #{stats_for(tiers_experiments[30_000], number_of_experiments)}"

        # Print tier probabilities
        puts ""
        puts "Tier Probabilities:"
        puts "Tier 0   POLS: #{tiers_experiments[0][:percentage]}"
        puts "Tier 250 POLS: #{tiers_experiments[250][:percentage]}"
        puts "Tier 1k  POLS: #{tiers_experiments[1_000][:percentage]}"
        puts "Tier 3k  POLS: #{tiers_experiments[3_000][:percentage]}"
        puts "Tier 10k POLS: #{tiers_experiments[10_000][:percentage]}"
        puts "Tier 30k POLS: #{tiers_experiments[30_000][:percentage]}"

        # Print top holders
        balances_without_whales = balances.reject { |(addr, _)| blacklist.include?(addr) }
        top_holders = balances_without_whales.sort_by { |(k,v)| v }.last(LotteryService::DEFAULT_TOP_N_HOLDERS).map(&:first)
        top_holders.each { |address| puts "#{address}: #{probabilities_hash[address]}" }

        # Final veredict
        expect(probabilities_hash.values.sum).to eq(LotteryService::DEFAULT_MAX_WINNERS)

        # Whales are not included in tol holders
        expect((top_holders - blacklist).count).to eq(10)

        # Top 10 holders have 100% probability to enter
        top_holders.each { |address| expect(probabilities_hash[address]).to eq(1.0) }

        # Expect specific percentage of winners per each tier
        expect(tiers_experiments[0][:percentage]).to be_nan
        expect(tiers_experiments[250][:percentage]).to    be_around(0.96,  error: error)
        expect(tiers_experiments[1_000][:percentage]).to  be_around(4.15,  error: error)
        expect(tiers_experiments[3_000][:percentage]).to  be_around(10.25, error: error)
        expect(tiers_experiments[10_000][:percentage]).to be_around(37.70, error: error)
        expect(tiers_experiments[30_000][:percentage]).to be_around(76.15, error: error)
      end
    end
  end
end
