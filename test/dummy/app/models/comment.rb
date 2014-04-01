class Comment < ActiveRecord::Base
  has_many :likes
end
