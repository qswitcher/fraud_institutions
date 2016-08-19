require 'nokogiri'
require 'csv'
require 'json'

schools = {}

def clean(txt)
    txt.gsub(/\[\d+\]/,'').gsub(/(\(page does not exist\))|(\(disambiguation\))|(\(online\))/, '').strip
end

def colorize(text, color_code)
  "\033[#{color_code}m#{text}\033[0m"
end

def red(text); colorize(text, 31); end
def green(text); colorize(text, 32); end
def blue(text); colorize(text, 34); end


def smart_add!(schools, school, source)
    name = school[:name]
    unless name.nil?
        school.delete(:name)
        if schools.include? name
            schools[name][source] = school
        else
            schools[name] = {
                source => school
            }
        end
    else
        puts "Nil detected!"
    end
end

countries = JSON.parse(File.read('countries.json'))
countries = countries['values']
US = (countries.select { |country| country[1] == 'United States' }).first
states = JSON.parse(File.read('states.json'))

# Wikipedia entries
wiki = 'Wikipedia'
page = Nokogiri::HTML(open('wiki_frauds.html'))
school_els = page.css('#mw-content-text > ul > li')
school_els.each do |el|
    description = clean(el.text)
    a = el.css('a').first
    school = {}
    if !a.nil?
        name = clean(a.text)
        href = a.attr('href')
        school[:name] = name
        school[:text] = description
        title = a.attr('title')
        if !title.nil? && !title.include?('page does not exist')
            school[:href] = href
        end
    else
        school[:name] = description
    end

    countries.each do |c|
        if description.include? c[1]
            school[:country_id] = c[0]
        end
    end

    if !school[:name].nil? && school[:name].strip().size > 0
        smart_add!(schools, school, wiki)
    end
end

# Glen wood diploma mills
glen_wood = 'Bogus University Directory TACRAO 2010'
CSV.foreach('glen_wood_diploma_mills.csv', col_sep: '|') do |row|
    description = row[1]
    school = {
        location: description,
        name: row[0]
    }

    # check countries
    countries.each do |c|
        if description.include? c[1]
            school[:country_id] = c[0]
        end
    end

    # check States
    states.each do |state|
        if description.include?(state[0]) || description.include?(state[1])
            school[:country_id] = US[0] # hardcoded to US
        end
    end

    smart_add!(schools, school, glen_wood)
end

# Glen wood closed diploma mills
CSV.foreach('glen_wood_closed_diploma_mills.csv', col_sep: '|') do |row|
    description = row[1]
    school = {
        text: description,
        name: row[0]
    }

    smart_add!(schools, school, glen_wood)
end

# thecb
thecb = 'Texas Higher Education Coordinating Board'
page = Nokogiri::HTML(open('THECB.html'))
school_els = page.css('tbody > tr')
school_els.each do |el, index|
    if index == 0
        next
    end

    tds = el.css('td')
    if tds.length > 0
        school = {
            name: clean(tds[0].text),
            location: clean(tds[1].text),
            text: clean(tds[2].text)
        }

        countries.each do |c|
            if school[:text].include? c[1]
                school[:country_id] = c[0]
            end
        end

        smart_add!(schools, school, thecb)
    end
end

# GRADE institutions
institutions = JSON.parse(File.read('grade_institutions.json'))['values']
institutions = institutions.sort { |left, right| left[1] <=> right[1] }
grade_institutions = {}
institutions.each do |institution|
    grade_institutions[institution[1]] = institution
end

schools = schools.each do |key, school|
    if grade_institutions.include?(key)
        school[:grade_id] = grade_institutions[key][0]
        p grade_institutions[key][0]
    end
    text = ''
    if school.include?(thecb)
        data = school[thecb]
        school[:recognition_type] = 'Substandard'
        text += "The Texas Higher Education Coordinating Board (as of May 2016) includes this institution on the <a href='http://www.thecb.state.tx.us/index.cfm?objectid=EF4C3C3B-EB44-4381-6673F760B3946FBB' target='_blank'>List of Institutions Whose Degrees are Illegal to Use in Texas</a>"
        unless data[:text].nil?
            text += " with the following remarks: '#{data[:text]}'."
        else
            text += "."
        end

        # TODO add country id logic
        if school.include?(glen_wood) || school.include?(wiki)
            text += '<br/><br/>'
        end

        school[:country_id] = data[:country_id]

    end

    if school.include?(glen_wood)
        data = school[glen_wood]
        school[:recognition_type] = 'Substandard'
        text += "This institution is listed on the Bogus University Directory compiled by Glen Wood in 2010 for the Texas Association for Collegiate Registrars and Admissions Officers (TACRAO)"

        unless data[:location].nil? || data[:location].strip.length == 0
            text += ", which notes its location as '#{data[:location]}'."
        else
            text += "."
        end

        if school.include?(wiki)
            text += '<br/><br/>'
        end

        if school[:country_id].nil?
            school[:country_id] = data[:country_id]
        end
    end

    if school.include?(wiki)
        data = school[wiki]

        if school[:recognition_type].nil?
            school[:recognition_type] = 'Unrecognized'
        end
        text += "The Wikipedia <a href='https://en.wikipedia.org/wiki/List_of_unaccredited_institutions_of_higher_education' target='_blank'>List of Unaccredited Institutions of Higher Education</a> (as of May 2016) notes this institution as '#{data[:text]}'."

        if school[:country_id].nil?
            school[:country_id] = data[:country_id]
        end
    end
    school[:text] = text

end

# schools_merged = schools.clone.merge(grade_institutions) do |key, oldvalue, newvalue|
#     oldvalue[:grade_institution] = newvalue
#     oldvalue
# end

# schools_merged.keys.to_a.sort.each do |name|
#     #descriptions = schools[name][:descriptions]
#     #sources = descriptions.inject('') { |acc, val| val[:source] + ', ' + acc}
#     #p "#{name.ljust(50)} #{descriptions.length.to_s.ljust(4)} #{sources}"
#     school = schools_merged[name]
#     if school.is_a?(Hash)
#         # it's an imported school
#         if school[:grade_institution].nil?
#             # it's an unmatched school
#             puts green(name)
#         else
#             puts red(name)
#         end
#     else
#         puts blue(name)
#     end
# end



puts "#{schools.length} total mills"
puts "#{(schools.clone.keep_if { |key, value| value[:grade_id].nil?}).length} new schools"
puts "#{(schools.clone.keep_if { |key, value| !value[:grade_id].nil?}).length} existing schools"


#
# schools.keys.to_a.sort.each do |school_name|
#     value = schools[school_name]
#     puts blue(school_name)
#     puts red(value[:description_addendum])
#     value[:descriptions].each do |source|
#         puts red("  #{source[:source]}")
#         source.each do |key, value|
#             if key != :source
#                 puts green("    #{key.to_s.ljust(10)} #{value}")
#             end
#         end
#     end
# end

File.delete('schools.json')
File.open('schools.json', 'w') do |f|
    f.puts schools.to_json
end
