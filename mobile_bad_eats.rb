#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'csv'
require 'open-uri'
require 't'
require 'pry'

puts "========== #{Time.now} Start =========="
DOC_ROOT = 'http://mchd.org/General/Restaurant_Ratings.aspx'

# Define inspection struct
InspectionReport = Struct.new(:inspection_date, :score, :establishment, :address, :city) do
  def to_a
    [inspection_date,score,establishment,address,city]
  end

  def to_tweet
    "#{establishment} scored #{score} on #{inspection_date}"
  end

  def to_s
    "#{score} :: #{inspection_date} :: #{establishment} :: #{address} :: #{city}"
  end
end

# build inspection history
inspection_history = []
CSV.foreach('history.csv') do |row|
  inspection_date = row[0]
  inspection_date = Date.strptime(row[0], '%Y-%m-%d')
  score = row[1].to_i
  establishment = row[2]
  address = row[3]
  city = row[4]
  inspection_history << InspectionReport.new(inspection_date, score, establishment, address, city)
end

doc = Nokogiri::HTML(open(DOC_ROOT))
score_table = doc.search("table[@id='restrating']")
rows = score_table.search('tr')

inspections = []
rows.each_with_index do |tr, i|
  # skip header row
  next if i == 0

  establishment = tr.children[0].text
  address = tr.children[1].text
  city = tr.children[2].text
  inspection_date = Date.strptime(tr.children[3].text, '%m/%d/%Y')
  score = tr.children[4].text.to_i
  inspections << InspectionReport.new(inspection_date, score, establishment, address, city)
end

# sort in ascending order
inspections.sort! { |a,b| a.inspection_date <=> b.inspection_date }

# tweet sub-85 inspections
sub_85_inspections = []
inspections.each do |inspection|
  if (!inspection_history.include?(inspection)) && (inspection.score < 85)
    sub_85_inspections << inspection
    puts inspection.to_s

    # specify twitter account to use
    cmd = "t set active Mobile_Bad_Eats"
    system(cmd)

    # post tweet
    cmd = "t update \"#{inspection.to_tweet}\""
    puts cmd
    system(cmd)
  end
end

# write sub_85_inspections to history
if sub_85_inspections.count > 0
  CSV.open('history.csv','a+') do |csv|
    sub_85_inspections.each do |hit|
      csv << hit.to_a
    end
  end
end

puts "========== #{Time.now} Done! =========="
exit 0
