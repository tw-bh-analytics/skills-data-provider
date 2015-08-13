#!/usr/bin/env ruby
require 'commander/import'
require 'httparty'

DEFAULT_DELAY = 1

program :version, '0.1'
program :description, 'Downloads Jigsaw data and convert it to CSV'

base_url = 'https://jigsaw.thoughtworks.com/api'

available_skills = {}

command :prepare_for_recommendation do |c|
  c.description = 'Prepare data for recommendation'
  c.syntax = "#{program(:name)} prepare_for_recommendation <skill_ratings_file> <skills_file> <people_file> <token>"
  c.option '--working_office STRING', String, 'Working office'
  c.option '--delay NUMBER', Integer, 'Delay (in seconds) between consecutive attempts to get people information from Jigsaw'

  c.action do |args, options|
    skill_ratings_file = open(args.shift || fail('Skill ratings file is required'), 'w')
    skills_file = open(args.shift || fail('Skills file is required'), 'w')
    people_file = open(args.shift || fail('People file is required'), 'w')
    token = args.shift || fail('The authorization token is required')
    url = "#{base_url}/people"
    delay = options.delay || DEFAULT_DELAY
    result = []
    page = 1
    begin
      query = { 'page' => page }
      query['working_office'] = options.working_office unless options.working_office.nil?
      result = HTTParty.get(url, query: query, headers: { "Authorization" => token })
      result.each do |person|
        person = {
          id: person['employeeId'],
          name: person['preferredName'],
          role: person['role']['name'],
          grade: person['grade']['name']
        }
        puts "Importing #{person[:name]}..."
        write_person(person, people_file)
        skills = HTTParty.get("#{url}/#{person[:id]}/skills", headers: { "Authorization" => token })
        skills.each do |skill|
          skill_name = "#{skill['group']['name']}/#{skill['name']}".strip
          skill_id = available_skills.length
          if available_skills.has_key? skill_name
            skill_id = available_skills[skill_name]
          else
            available_skills[skill_name] = skill_id
          end
          line = "#{person[:id]},#{skill_id},#{skill['rating']}\n"
          skill_ratings_file.write(line)
        end
        puts "Finished importing #{person[:name]}!"
        puts "Delaying #{delay} seconds for Jigsaw API usage limits compliance..."
        sleep delay
      end
      page += 1
    end while result.empty?

    skill_ratings_file.close
    people_file.close

    available_skills.each_pair do |skill_name, skill_id|
      skills_file.write("#{skill_name.gsub(',', ' &')},#{skill_id}\n")
    end
    skills_file.close
  end
end

def write_person(person, file)
  file.write("#{person[:id]},#{person[:name]},#{person[:role]},#{person[:grade]}\n")
end
