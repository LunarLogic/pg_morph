class Comment < ActiveRecord::Base
  has_many :likes, as: :likeable
end
