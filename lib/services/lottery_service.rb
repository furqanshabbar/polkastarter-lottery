#require_relative '../models/participant'
#require File.dirname(__FILE__) + '/../models/participant'
require 'models/participant'

class LotteryService
  attr_reader :balances         # e.g: { '0x71C7656EC7ab88b098defB751B7401B5f6d8976F' => 3000 }
  attr_reader :recent_winners   # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F']
  attr_reader :past_winners     # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F']
  attr_reader :blacklist        # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F']

  attr_reader :all_participants # all candidates
  attr_reader :participants     # only eligible ones
  attr_reader :winners          # only winners

  MAX_WINNERS = 500.freeze
  TOP_N_HOLDERS = 10.freeze
  PRIVILEGED_NEVER_WINNING_RATIO = 0.10.freeze

  def initialize(balances:, recent_winners: [], past_winners: [], blacklist: [])
    @balances = balances
    @recent_winners = recent_winners
    @past_winners = past_winners.map &:downcase
    @blacklist = blacklist
  end

  def run
    @all_participants = build_participants.sort # sort desc by balance
    @participants = all_participants.select { |participant| !top_holder?(participant) } # top holders are excluded from shuffling because they will always enter
    @participants = participants.select { |participant| participant.eligible? }.sort # sort desc by balance

    @winners = calculate_winners
  end

  private

  def calculate_winners
    winners = []

    winners += top_holders
    winners += privileged_participants
    winners += shuffled_eligible_participants

    winners.uniq.first MAX_WINNERS
  end

  def top_holders
    all_participants.first TOP_N_HOLDERS
  end

  def top_holder?(participant)
    top_holders.include? participant.address
  end

  def privileged_participants
    sample_size = MAX_WINNERS * PRIVILEGED_NEVER_WINNING_RATIO
    never_winning_participants.sample sample_size
  end

  def shuffled_eligible_participants
    participants.sort_by do |participant|
      - participant.weight * rand()
    end
  end

  def never_winning_participants
    participants.select do |participant|
      !past_winners.include? participant.address
    end
  end

  def build_participants
    balances.map do |address, balance|
      next if blacklist.include? address
      Participant.new address:               address,
                      balance:               balance,
                      recently_participated: recent_winners.include?(address)
    end.compact
  end
end
