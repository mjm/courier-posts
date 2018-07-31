class Tweet < Sequel::Model(DB[:tweets])
  many_to_one :post
end
