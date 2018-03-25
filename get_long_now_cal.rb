#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'icalendar'
require 'icalendar/tzinfo'

def find_upcoming_seminar_uris(url)
  seminars_page = Nokogiri::HTML(open(url))
  
  next_seminar_url = seminars_page.at_css('a#next_seminar')['href']
  upcoming_seminar_urls = seminars_page.css('marquee a.loud').map {|link| link['href']}
  
  upcoming_seminar_urls << next_seminar_url
  upcoming_seminar_urls.map {|upcoming| URI(url).merge(upcoming)}
end

def extract_event_url(page)
  meta_items = page.css('ul.upcoming_seminar_meta li')
  cal_item = meta_items.select {|li| li['title'] =~ /calendar/i}
  cal_item.first.at('a')['href']
end
  

def get_first_event_from_url(url)
  parsed = Icalendar::Calendar.parse(open(url)) #returns array of calendars
  # TODO: Add proper timezone info
  event = parsed.first.events.first
end

VERSION = "1.0"

SEMINAR_LIST_URI = URI("http://longnow.org/seminars/")
CONVERSATION_LIST_URI = URI("https://theinterval.org/salon-talks/all")

calendar = Icalendar::Calendar.new
calendar.prodid = "Long Now Cal Scraper v#{VERSION} https://github.com/purp/long_now_cal_scraper"
tz = TZInfo::Timezone.get("America/Los_Angeles")
calendar.add_timezone(tz.ical_timezone(DateTime.new(1999, 6, 19, 19, 15, 0)))


# Fetch seminars page URLs from  http://longnow.org/seminars/list/
find_upcoming_seminar_uris(SEMINAR_LIST_URI).each do |seminar_uri|
  puts ">>> Seminar URI: #{seminar_uri}"
  page = Nokogiri::HTML(open(seminar_uri))
  
  event_uri = seminar_uri.merge(extract_event_url(page))
  puts ">>> Event URI: #{event_uri}"
  
  # TODO: Make UID of events stable; currently generates UID new each time
  event = get_first_event_from_url(event_uri)

  speaker = page.at('h1').text
  talk_title = page.at('h2').text
  location_gmaps_url = page.at('li.map a')['href']
  live_stream_url = 'http://longnow.org/live/'
  ticket_link = page.at('div.tickets_rsvp_bigbutton div span.large a')
  # Sometimes there isn't a ticket link yet
  ticket_url = ticket_link ? ticket_link['href'] : "No Link Yet"
  
  description = [
    "TIX: #{ticket_url}",
    "MAP: #{location_gmaps_url}",
    "STREAM: #{live_stream_url}",
    page.at('//comment()[contains(.,"Introduction")]').next_element.text
  ]
  
  event.summary = "#{speaker}: #{talk_title}"
  event.description = description.join("\n")
  event.location = page.at_css('li.map a').inner_text
  event.url = seminar_uri
  
  calendar.add_event(event)
end

# TODO: parse out calendar events with links to previous

# Write out iCal file
open("./long_now_calendar.ics", "w") {|cal|
  cal.write(calendar.to_ical)
}

