# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create sample customers
puts "Creating sample customers..."

customer1 = Customer.create!(
  name: "John Doe",
  email: "john@example.com",
  company: "Acme Corp",
  notes: "Main customer for testing"
)

customer2 = Customer.create!(
  name: "Jane Smith",
  email: "jane@techstart.com",
  company: "TechStart Inc",
  notes: "Technology startup customer"
)

# Create phone numbers for customers
puts "Creating phone numbers..."

phone1 = PhoneNumber.create!(
  customer: customer1,
  number: "555-123-4567",
  display_name: "Main Line",
  description: "Primary business phone",
  is_primary: true
)

phone2 = PhoneNumber.create!(
  customer: customer1,
  number: "555-123-4568",
  display_name: "Support Line",
  description: "Customer support phone",
  is_primary: false
)

phone3 = PhoneNumber.create!(
  customer: customer2,
  number: "555-987-6543",
  display_name: "Sales",
  description: "Sales department phone",
  is_primary: true
)

# Create sample FAQs
puts "Creating sample FAQs..."

Faq.create!(
  phone_number: phone1,
  title: "Business Hours",
  content: "We are open Monday through Friday, 9 AM to 5 PM EST."
)

Faq.create!(
  phone_number: phone1,
  title: "Company Website",
  website_url: "https://www.acmecorp.com",
  content: "Visit our website for more information"
)

Faq.create!(
  phone_number: phone2,
  title: "Support Documentation",
  website_url: "https://support.acmecorp.com/docs",
  content: "Access our support documentation online"
)

puts "Seed data created successfully!"
puts "Customers: #{Customer.count}"
puts "Phone Numbers: #{PhoneNumber.count}"
puts "FAQs: #{Faq.count}"
