#require 'micro_spider'
require 'mechanize'
require 'logger'
module MovieSpider

  class Tudou
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @logger = Logger.new(STDOUT)
    end
  
    # 获取每一个播放页面的相关信息
    def get_page_info
      infos = []
      urls  = get_play_url
      urls.each do |url|
        @logger.info  "=============>  runing tudou  #{url}  <=============="
        begin
          infos << start_crawl(url)
        rescue
          @logger.info '--------------------------tudou error while executing next url start--------------------------'
          @logger.info  url
          @logger.info '--------------------------tudou error while executing next url end  --------------------------'
          next
        end
      end
      return infos
    end
  
    #到土豆网的电影详情页面去抓取所有能播放的url,这些url包括预告和花絮
    def get_play_url
      urls = []
      post_url    = get_post_url
      page = get_prev_feature_response
      if page.present?
        prev_url    = get_prev_url(page)
        feature_url = get_feature_url(page)
        urls        = (post_url + prev_url + feature_url).uniq
      end
      return urls
    end
  
    # 获取介绍页海报处的url
    def get_post_url
      return unless @path.include?('albumcover')
      res = []
      uri  = URI::decode(@path)
      page = get_page(uri)
      if page.present?
        res = [page.search('.pic a').attr('href').value]
      end
      return res
    end
  
    # 获取预告片的链接地址  
    def get_prev_url(page)
      prev_url = []
      JSON.parse(page.body)['previewsPlaylistItems'].each do |item|
        prev_url << item['otherPlayUrl']
      end
      return prev_url
    end
  
    # 获取花絮的链接地址
    def get_feature_url(page)
      feature_url = []
      JSON.parse(page.body)['featurettesItems'].each do |item|
        feature_url << item['otherPlayUrl']
      end
      return  feature_url 
    end
  
    # 生成爬虫实例
    def generate_spider
      spider = MicroSpider.new
      spider.delay = 2
      return spider 
    end
  
    # 获取预告片及花絮的链接地址
    def get_prev_feature_response
      return unless @path.include?('albumcover')
      code = @path.split('/').last.split('.').first
      uri = URI("http://www.tudou.com/albumcover/albumdata/getOtherAlbumItemInfoes.action?acode=#{code}")
      res = get_page(uri)
      return res
    end
  
    # 拿到视频id并开始抓取数据
    def get_play_info(url)
      page  = get_page(url)
      if page.present?
        title = page.search('#videoKw').text.gsub(/\s+/,'')
        iid   = nil
        page.search('script').each do |script|
          unless script.attr('src').present?
            if script.content.include?('var pageConfig')
              script.content.split(',').each do |sc|
                if sc.match(/iid:/)  
                  iid = sc.scan(/\d+/).first
                end
              end
            end
          end
        end
        return get_play_num(url,iid,title)
      else
        return nil
      end
    end
    # 返回抓取数据
    def get_play_num(url,iid,title)
      hash = Hash.new(0)
      hash[:url]   = url
      hash[:type]  = url.include?('albumplay') ? '正片' : '预告'
      hash[:title] = title
      uri = URI("http://www.tudou.com/crp/itemSum.action?jsoncallback=page_play_model_itemSumModel__find&app=6&showArea=true&iabcdefg=#{iid}&uabcdefg=0&juabcdefg=019ev33tal293i")
      res = get_page(uri)
      if res.present?
        res.body.split(',').each do |num|
          hash[:commentNum] =  num.scan(/\d+/).first  if num.match(/commentNum/)
          hash[:upNum]      =  num.scan(/\d+/).first  if num.match(/digNum/)
          hash[:playNum]    =  num.scan(/\d+/).first  if num.match(/playNum/)
          hash[:downNum]    =  0
        end
      end
      return hash
    end

    def get_page(url)
      url  = url.to_s
      agent = Mechanize.new do |a| 
        #a.keep_alive = false
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
      end 

      page = nil
      url  = url.gsub(/\s+/,'')
      uri = URI(url)
      #TODO 如果请求频繁的话有可能会被拒绝,可以在这里加上sleep
      # sleep(1)
      begin 
        page = agent.get uri  
      rescue
        @logger.info  '-------------tudou get agent.page error start -------------'
        @logger.info  url
        @logger.info  '-------------tudou get agent.page error end -------------'
      end
      
      return page
    end
    # 开始抓取
    def start_crawl(url)
      data = get_play_info(url)
    end
   end
end


