class Request < Sequel::Model(:requests)
  def before_create
    normalize_url!
    refresh!
    super
  end

  def normalize_url!
    uri = URI.parse(url)
    uri.query &&= uri.query.split('&').sort.join('&')
    self.url = uri.to_s
  end

  def refresh!
    @last_page_id = @doc = nil
    is_new = last_page_id != page_id
    self.page_id = last_page_id
    is_new
  end

  def doc
    @doc ||= Nokogiri::HTML(open(url))
  end

  def last_page_id
    @last_page_id ||= /\/(\d+).htm/.match(doc.css('div.list-ads > a:first-child').first[:href])[1]
  end
end
