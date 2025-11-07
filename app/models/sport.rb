class Sport < ApplicationRecord
  has_many :categories, dependent: :destroy
end
