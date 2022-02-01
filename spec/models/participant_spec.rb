require 'spec_helper'

RSpec.describe Participant, type: :model do
  describe 'tickets' do

    context 'given balance is nil' do
      let(:participan) { Participant.new(address: 'AAAA', balance: nil) }
      it 'return tickets = 0' do
        expect(participan.tickets).to eq(0)
      end
    end

    context 'given balance is negative' do
      let(:participan) { Participant.new(address: 'AAAA', balance: -1) }
      it 'return tickets = 0' do
        expect(participan.tickets).to eq(0)
      end
    end

    context 'given balance is 0' do
      let(:participan) { Participant.new(address: 'AAAA', balance: 0) }
      it 'return tickets = 0' do
        expect(participan.tickets).to eq(0)
      end
    end

    context 'given balance is 1' do
      let(:participan) { Participant.new(address: 'AAAA', balance: 1) }
      it 'return tickets = 0' do
        expect(participan.tickets).to eq(0)
      end
    end

    context 'given balance is 250' do
      let(:participan) { Participant.new(address: 'AAAA', balance: 250) }
      it 'return tickets = 1' do
        expect(participan.tickets).to eq(1)
      end
    end

    context 'given balance is 30_000' do
      let(:participan) { Participant.new(address: 'AAAA', balance: 30_000) }
      it 'return tickets = 150' do
        expect(participan.tickets).to eq(150)
      end
    end
  end
end