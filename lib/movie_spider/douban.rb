#require 'micro_spider'
require 'mechanize'
module MovieSpider
  class Douban
    def initialize(path)
      @path = path
    end  	
    def get_basic_info
      result_hash = {}
      uri = URI("#{@path}")
      res = get_page(uri)

      info_arr  = res.search('#info').text.split(/\n+/).map{|ele| ele.gsub(/\s+/,'')}
      info_arr  = info_arr.delete_if{|ele| ele.length == 0}
      info_hash = Hash.new(0) 
      info_arr.each do |info|
      	info_hash[:director] = info.split(':').last if info.match(/导演/)
      	info_hash[:writer]   = info.split(':').last if info.match(/编剧/)
      	info_hash[:actor]    = info.split(':').last if info.match(/主演/)
      	info_hash[:type]     = info.split(':').last if info.match(/类型/)
      	info_hash[:area]     = info.split(':').last if info.match(/地区/)
      	info_hash[:language] = info.split(':').last if info.match(/语言/)
      	info_hash[:length]   = info.split(':').last if info.match(/片长/)
      end
      info_hash[:desc] = res.search('span[property="v:summary"]').text.gsub(/\s+/,'') 

      info_hash.each do |k,v|
        info_hash[k.to_sym] = '' if v.to_s == '0'
      end
      return info_hash
    end

    def get_page(uri)
      agent = Mechanize.new do |a| 
        #a.keep_alive = false
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
      end       
      uri = URI("#{uri}")
      page = agent.get uri
      return page    	
    end
  end
end






