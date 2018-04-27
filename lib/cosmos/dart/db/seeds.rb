# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
status = Status.first
unless status
  status = Status.new
  time = Time.utc(1970, 1, 1)
  status.decom_message_time = time
  status.reduction_message_time = time
  status.save!
end
