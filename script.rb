require 'nokogiri'
require 'csv'
require 'json'

schools = {}

def clean(txt)
    txt.gsub(/\[\d+\]/,'').strip
end

def smart_add!(schools, school)
    name = school[:name]
    school.delete(:name)
    if schools.include? name
        schools[name][:descriptions].push(school)
    else
        schools[name] = {
            descriptions: [school]
        }
    end
end

countries = JSON.parse(File.read('countries.json'))
countries = countries['values']

# Wikipedia entries
page = Nokogiri::HTML(open('wiki_frauds.html'))
school_els = page.css('#mw-content-text > ul > li')
school_els.each do |el|
    description = clean(el.text)
    a = el.css('a')
    school = {
    }
    if a.size > 0
        name = clean(a.text)
        href = a.attr('href')
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

    school[:source] = 'Wikipedia'
    if !school[:name].nil? && school[:name].strip().size > 0
        name = school[:name]
        school.delete(:name)
        schools[name] = {
            descriptions: [school]
        }
    end
end

# Glen wood diploma mills
CSV.foreach('glen_wood_diploma_mills.csv', col_sep: '|') do |row|
    school = {
        text: row[1],
        source: 'Glen Wood'
    }
    if schools.include? row[0]
        schools[row[0]][:descriptions].push(school)
    else
        schools[row[0]] = {
            descriptions: [school]
        }
    end
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
            source: 'THECB'
        }

        countries.each do |c|
            if school[:text].include? c[1]
                school[:country] = c
            end
        end

        smart_add!(schools, school)
    end
end

schools.each do |row|
    p "#{row[0].to_s.ljust(50)} #{row[1][:descriptions].length.to_s.ljust(4)}"
end
p "Number of schools #{schools.length}"
#
# CSV.open('fraud_out.csv', 'w') do |csv|
#     schools.each do |school|
#         csv << [school[:name], school[:href], school[:country].nil? ? nil : school[:country][0],  school[:country].nil? ? nil : school[:country][1], school[:description]]
#     end
# end
