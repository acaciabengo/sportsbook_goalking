class CrownPointTransaction < ApplicationRecord
  belongs_to :bet_slip
  belongs_to :user
end
