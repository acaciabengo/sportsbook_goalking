class SlipBonus < ApplicationRecord
	audited
    validates :min_accumulator, presence: true
	validates :max_accumulator, presence: true
	validates :multiplier, presence: true

	self.table_name = 'slip_bonuses'
end
