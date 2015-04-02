require 'mechanize'
require 'logger'
module MovieSpider
  class Qq
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @cid  = nil
      @logger = Logger.new(STDOUT)
    end
  
    # 获取每一个播放页面的相关信息
    def get_page_info
      infos = []
      urls  = get_play_url
      urls  = urls[0,30]
      vids  = urls.map{|hash| hash[:url].split('?vid=').last}.join('|')
      url   = URI.encode("http://sns.video.qq.com/tvideo/fcgi-bin/batchgetplaymount?id=#{vids}&otype=json")
      page  = get_page(url)
      if page.present?
        res = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
        if res['node'] && res['node'].length > 0
          res['node'].each do |node|
            id  = node['id'].gsub(/\s+/,'')
            tmp_hash = urls.select{|url_hash| url_hash[:url].include?("vid=#{id}")}.first
            if node['all_m'].present?
              tmp_hash.merge!({playNum:node['all_m'].to_i,tdPlayNum:node['td'].to_i,yestPlayNum:node['yest'].to_i})
            else
              tmp_hash.merge!({playNum:node['all'].to_i,tdPlayNum:node['td'].to_i,yestPlayNum:node['yest'].to_i})
            end
              tmp_hash.merge!({commentNum:get_comments_count,upNum:get_up_down_count.first,downNum:get_up_down_count.last})
          end
        end
      end

      return urls

# "node":[
#   {"all":51032103,"all_m":23478307,"id":"jhfdhwzqk29f41m","num":51032103,"td":4506,"td_m":4110,"yest":10013,"yest_m":9402},
#   {"all":23074148,"id":"c00145fgfjg","num":23074148,"td":4160,"yest":9328},
#   {"all":295881,"id":"t0014ztyc58","num":295881,"td":18,"yest":31},
#   {"all":108359,"id":"h00149vuym6","num":108359,"td":13,"yest":43},
#   {"all":172602,"id":"j0014p08mla","num":172602,"td":9,"yest":19},
#   {"all":559252,"id":"m0014zd9sak","num":559252,"td":5,"yest":9},
#   {"all":45370,"id":"q0014zioxst","num":45370,"td":1,"yest":1},
#   {"all":96298,"id":"i00145gtbp4","num":96298,"td":4,"yest":2},
#   {"all":406142,"id":"z0014yh58fg","num":406142,"td":0,"yest":4},
#   {"all":158961,"id":"z00147knbr2","num":158961,"td":5,"yest":6},
#   {"all":135940,"id":"u0014ggv2dj","num":135940,"td":4,"yest":5},
#   {"all":238382,"id":"o00148t84yq","num":238382,"td":4,"yest":13}
# ],"result":0}



      # urls.each do |hash|
      #   @logger.info "=============>  runing tecent  #{hash[:url]} <=============="
      #   begin
      #     data = start_crawl(hash)
      #     infos << data if data.present?          
      #   rescue
      #     @logger.info '--------------------------qq error while executing next url start--------------------------'
      #     @logger.info hash[:url]
      #     @logger.info '--------------------------qq error while executing next url end  --------------------------'
      #     next
      #   end
      # end
      infos.delete_if{|e| e[:url] == nil }
      return infos
    end
  
    def get_play_url
      id       = @path.split('/').last.split('.').first
      @cid     = get_comment_id(id)
      post_url = get_post_url(id)
      prev_url = get_pre_urls(id)
      urls     = (post_url + prev_url).uniq
      return urls
    end
  
    # 获取介绍页海报处的url
    def get_post_url(id)
      url   = "http://s.video.qq.com/loadplaylist?vkey=897_qqvideo_cpl_#{id}_qq&vtype=2&otype=json&video_type=1"
      page  = get_page(url)
      hash  = Hash.new(0)
      url   = []
      if page.present?
        res = page.body.split(/\(/).split(/\)/).first[0]
        res = res.gsub('QZOutputJson=','').gsub(';','')
        res = JSON.parse(res)  
        if res['video_play_list'].present? && res['video_play_list']['total_episode'].present?
          total_episode = res['video_play_list']['total_episode'].to_i
        end
        # 0 为其他网站播放源
        # 1 表示为正片
        # 大于1表示目前没有正片
        @logger.info "~~~~~~~~~~~~~~~~~~~~~~~~~~~ #{@path} ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        if total_episode && total_episode > 0
          if total_episode == 1
            hash[:type] = '正片'
          elsif total_episode > 1
            hash[:type] = '预告片'
          end
          hash[:title]  = res['video_play_list']['playlist'][0]['title']
          hash[:url]    = res['video_play_list']['playlist'][0]['url']
        else
          @logger.info "---------------- #{@path} --------------  该影片的播放源不在腾讯 ------- 无预告列表 --------"
        end
      end
      return url
    end

    # 获取海报链接处播放源的id
    def get_id
      pth = @path.split('/').last.split('.').first
      uri = URI("http://s.video.qq.com/loadplaylist?vkey=897_qqvideo_cpl_#{pth}_qq&otype=json")
      pg  = get_page(uri)
      if pg.present?
        res = JSON.parse(pg.body.gsub('QZOutputJson=','').gsub(';',''))  
        return res['video_play_list']['playlist'][0]['id']
      end
    end
  
  
    # 生成爬虫实例
    def generate_spider
      spider = MicroSpider.new
      spider.delay = 2
      return spider 
    end
  
    # 获取预告片及花絮及mv的链接地址
    def get_pre_urls(id)
      url   = "http://s.video.qq.com/loadplaylist?otype=json&type=2&pagestart=1&num=96&id=#{id}"
      page  = get_page(url)
      hash  = Hash.new(0)
      urls  = []
      if page.present?


        res = page.body.split(/\(/).split(/\)/).first[0]
        res = res.gsub('QZOutputJson=','').gsub(';','')
        res = JSON.parse(res)
        if res.present? && res['video_play_list'].present? && res['video_play_list']['playlist'].present?
          res['video_play_list']['playlist'].each do |obj|
            urls << {url:obj['url'],title:obj['title'],type:'预告片'}
          end
        end        
      end
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
      if page.present?
        res  = JSON.parse(page.body)
        begin
          res  = res['data']['subject'][0]['option']
          return [res[0]['selected'],res[1]['selected']]
        rescue
          @logger.info '-----------------tecent  error while get up and down count start -----------------'
          @logger.info "#{@path}  没有顶和踩的数据"
          @logger.info uri
          @logger.info '-----------------tecent  error while get up and down count start -----------------'
          return [0,0]
        end      
      else
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
      if page.present?
        res  = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
        return res['comment_id']  
      else
        return 0
      end
    end
  
    # 获取视频的评论数量
    def get_comments_count
      uri = URI("http://coral.qq.com/article/#{@cid}/commentnum")
      page = get_page(uri)
      if page.present?
        res  = JSON.parse(page.body)
        return res['data']['commentnum']
      else
        return 0
      end
    end
  
    # 获取电影的播放量
    def get_play_count(vid)
      uri  = URI("http://sns.video.qq.com/tvideo/fcgi-bin/batchgetplaymount?id=#{vid}&otype=json&_=#{Time.now.to_i}")
      cnt  = 0
      page = get_page(uri)
      if page.present?
        res  = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
        cnt  = res['node'][0]['all'].to_i
        all_m = res['node'][0]['all_m'].to_i
        cnt = cnt - all_m  # for cctv project data
      end
      return cnt
    end
    
    # 开始抓取
    def start_crawl(hash)
      data = get_play_info(hash)
    end

    def get_page(url)
      url  = url.to_s  
      agent = Mechanize.new do |a| 
        #a.keep_alive = false
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
      end 


      agent.user_agent_alias = 'Mac Safari'
      page = nil
      url  = url.gsub(/\s+/,'')
      uri = URI(url)
      #TODO 如果请求频繁的话有可能会被拒绝,可以在这里加上sleep 
      # sleep(1)
      begin 
        page = agent.get uri  
      rescue
        @logger.info  '-------------qq get agent.page error start -------------'
        @logger.info  url
        @logger.info  '-------------qq get agent.page error end -------------'
      end      
      return page
    end    
  end
end
# qq = MovieSpider::Qq.new('http://v.qq.com/detail/e/er1k9kuvt4e79m7.html')
# qq.get_page_info
