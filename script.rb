require 'nokogiri'
require 'csv'
require 'json'

schools = {}

def clean(txt)
    txt.gsub(/\[\d+\]/,'').strip
end

def smart_add!(schools, school)
    name = school[:name]
    unless name.nil?
        school.delete(:name)
        if schools.include? name
            schools[name][:descriptions].push(school)
        else
            schools[name] = {
                descriptions: [school]
            }
        end
    else
        puts "Nil detected!"
    end
end

countries = JSON.parse(File.read('countries.json'))
countries = countries['values']
US = countries.select { |country| country[1] == 'United States' }
states = JSON.parse(File.read('states.json'))

# Wikipedia entries
page = Nokogiri::HTML(open('wiki_frauds.html'))
school_els = page.css('#mw-content-text > ul > li')
school_els.each do |el|
    description = clean(el.text)
    a = el.css('a')
    school = {
        source: 'Wikipedia'
    }
    if a.size > 0
        name = clean(a.text)
        href = a.attr('href').value
        school[:name] = name
        school[:text] = description
        title = a.attr('title')
        if !title.nil? && !title.text.include?('page does not exist')
            school[:href] = href
        end
    else
        school[:name] = description
    end

    countries.each do |c|
        if description.include? c[1]
            school[:country] = c
        end
    end

    if !school[:name].nil? && school[:name].strip().size > 0
        smart_add!(schools, school)
    end
end

# Glen wood diploma mills
glen_wood = 'Bogus University Directory TACRAO 2010'
CSV.foreach('glen_wood_diploma_mills.csv', col_sep: '|') do |row|
    description = row[1]
    school = {
        text: description,
        source: glen_wood,
        name: row[0]
    }

    # check countries
    countries.each do |c|
        if description.include? c[1]
            school[:country] = c
        end
    end

    # check States
    states.each do |state|
        if description.include?(state[0]) || description.include?(state[1])
            school[:country] = US # hardcoded to US
        end
    end

    smart_add!(schools, school)
end

# Glen wood closed diploma mills
CSV.foreach('glen_wood_closed_diploma_mills.csv', col_sep: '|') do |row|
    description = row[1]
    school = {
        text: description,
        source: glen_wood,
        name: row[0]
    }

    smart_add!(schools, school)
end

# thecb
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
            text: clean(tds[2].text),
            source: 'Texas Higher Education Coordinating Board'
        }

        countries.each do |c|
            if school[:text].include? c[1]
                school[:country] = c
            end
        end

        smart_add!(schools, school)
    end
end

# geteducated_com
CSV.foreach('geteducated_com.csv') do |row|
    school = {
        source: 'geteducated.com',
        name: row[0]
    }

    # is it in the US?
    if row.length > 1
        row[1...row.length].each do |item|
            states.each do |state|
                if item == state[0]
                    school[:country] = US # hardcoded to US
                end
            end
        end
    end

    smart_add!(schools, school)
end

schools.keys.to_a.sort.each do |name|
    descriptions = schools[name]
    p "#{name.ljust(50)} #{descriptions.length.to_s.ljust(4)}"
end
p "Number of schools #{schools.length}"
#
# CSV.open('fraud_out.csv', 'w') do |csv|
#     schools.each do |school|
#         csv << [school[:name], school[:href], school[:country].nil? ? nil : school[:country][0],  school[:country].nil? ? nil : school[:country][1], school[:description]]
#     end
# end
