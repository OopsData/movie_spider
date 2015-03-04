require 'micro_spider'

module MovieSpider

  class Qq
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @cid  = nil
    end
  
    # 获取每一个播放页面的相关信息
    def get_page_info
      infos = []
      urls  = get_play_url
      urls.each do |hash|
        puts "=============>  runing tecent  #{hash[:url]} <=============="
        begin
          data = start_crawl(hash)
          infos << data if data.present?          
        rescue
          puts'--------------------------qq error while executing next url start--------------------------'
          puts hash[:url]
          puts'--------------------------qq error while executing next url end  --------------------------'
          next
        end
      end
      infos.delete_if{|e| e[:url] == nil }
      return infos
    end
  
    def get_play_url
      page     = get_page(@path)
      vid      = get_vid(page)
      @cid     = get_comment_id(vid)
      post_url = get_post_url(page)
      prev_url = get_pre_urls(vid)    
      urls     = (post_url + prev_url).uniq
      return urls
    end
  
    # 获取介绍页海报处的url
    def get_post_url(page)
      return unless @path.include?('detail')
      url = []
      # 播放源
      source =  page.search('#cont_playsource  .link_source_default').attr('sourcename').value 
      if source.match(/qq/)
        # begin
          id     =  get_id
          href   =  @path.gsub('detail','cover')
          href   =  href + "?vid=#{id}"
          title  =  page.search('.video_title strong a').text
          type   = page.search('.mark_trailer').present? ?  '预告片' : '正片' 
          url << {url:href,title:title,type:type}  
        # rescue
        #   puts'--------------------------qq error while get post url start--------------------------'
        #   puts @path
        #   puts'--------------------------qq error while get post url end  --------------------------'          
        #   url = [{url:nil,title:nil}]
        # end
      end
      return url
    end

    # 获取海报链接处播放源的id
    def get_id
      pth = @path.split('/').last.split('.').first
      uri = URI("http://s.video.qq.com/loadplaylist?vkey=897_qqvideo_cpl_#{pth}_qq&otype=json")
      pg  = get_page(uri)
      res = JSON.parse(pg.body.gsub('QZOutputJson=','').gsub(';',''))
      return res['video_play_list']['playlist'][0]['id']
    end
  
  
    # 生成爬虫实例
    def generate_spider
      spider = MicroSpider.new
      spider.delay = 2
      return spider 
    end
  
    # 获取预告片及花絮及mv的链接地址
    def get_pre_urls(vid)
      #TODO
      # 腾讯视频的播放数评论数，赞数和踩数都一样(即所有预告片包括正片，这几个参数值都一样)
      urls  = []
      uri   = URI::encode("http://s.video.qq.com/loadplaylist?otype=json&type=2&pagestart=1&num=96&id=#{vid}")
      page  = get_page(uri)
      res   = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
      # begin
        res['video_play_list']['playlist'].each do |obj|
          urls << {url:obj['url'],title:obj['title'],type:'预告片'}
        end
      # rescue
      #   puts'--------------------------qq error while get pre urls start--------------------------'
      #   puts @path
      #   puts'--------------------------qq error while get pre urls end  --------------------------'
      #   urls << {url:nil,title:nil,type:nil}
      # end

      return urls
    end
  
    # 拿到视频id并开始抓取数据
    def get_play_info(hash_data)
      if hash_data[:url].present?
        hash = Hash.new(0)
        res  = get_basic_doc(hash_data[:url])
        vid  = hash_data[:url].split('vid=').last
        hash[:type]          = hash_data[:type] 
        hash[:title]         = hash_data[:title]
        hash[:url]           = hash_data[:url]
        hash[:playNum]    = get_play_count(vid)
        hash[:commentNum] = get_comments_count
        hash[:upNum]      = get_up_down_count.first
        hash[:downNum]    = get_up_down_count.last
        return  hash
      end
    end
  
    # 获取基本doc
    def get_basic_doc(url)
      uri = URI("#{url}")
      res = get_page(uri)
      return res
    end
  
    # 获取顶数量
    def get_up_down_count
      uri  = URI::decode("http://coral.qq.com/article/#{@cid}/voteinfo")
      page = get_page(uri)
      res  = JSON.parse(page.body)
      begin
        res  = res['data']['subject'][0]['option']
        return [res[0]['selected'],res[1]['selected']]
      rescue
        puts '-----------------tecent  error while get up and down count start -----------------'
        puts "#{@path}  没有顶和踩的数据"
        puts uri
        puts '-----------------tecent  error while get up and down count start -----------------'
        return [0,0]
      end
           
      
    end

    # 获取视频的id
    def get_vid(res)
      vid = nil
      res.search('script').each do |script|
        unless script.attr('src').present?
          if script.content.include?('var search_gconfig =')
            script.content.split('};').first.split(',').each do |con|
              vid = con.split(':').last.gsub(/\s+/,'')  if con.include?('vid') && !con.include?('vpic')
            end
          end
        end
      end
      return vid.gsub(/'/,'')
    end

    def get_comment_id(vid)
      uri = URI("http://sns.video.qq.com/fcgi-bin/video_comment_id?otype=json&op=3&cid=#{vid}")
      page = get_page(uri)
      res  = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
      return res['comment_id']
    end
  
    # 获取视频的评论数量
    def get_comments_count
      uri = URI("http://coral.qq.com/article/#{@cid}/commentnum")
      page = get_page(uri)
      res  = JSON.parse(page.body)
      return res['data']['commentnum']
    end
  
    # 获取电影的播放量
    def get_play_count(vid)
      uri  = URI("http://sns.video.qq.com/tvideo/fcgi-bin/batchgetplaymount?id=#{vid}&otype=json&_=#{Time.now.to_i}")
      page = get_page(uri)
      res  = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
      cnt  = res['node'][0]['all'].to_i
    end
    
    # 开始抓取
    def start_crawl(hash)
      data = get_play_info(hash)
    end

    def get_page(url)
      url  = url.to_s
      agent = Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page = nil
      url  = url.gsub(/\s+/,'')
      uri = URI(url)
      #TODO 如果请求频繁的话有可能会被拒绝,可以在这里加上sleep
      sleep(1)
      page = agent.get uri
      return page
    end    
  end
end
# qq = MovieSpider::Qq.new('http://v.qq.com/detail/e/er1k9kuvt4e79m7.html')
# qq.get_page_info
