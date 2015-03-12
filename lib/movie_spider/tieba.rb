require 'micro_spider'
require 'logger'
module MovieSpider
  class Tieba
    # path 表示要抓取的路径
    # file 表示从firefox导出的cookie.txt文件的绝对路径
    # limit 表示每个明星要抓取的pn值,这个pn指的是每次翻页的时候改变的那个pn值
    # limit 值约大,表示抓取数据的时间距离今天越远
    # limit 如果想要抓取前一天的数据(爬虫后半夜开始爬取前一天的数据),可以将这个值改小
    # 比如说1000,那么只收集昨天最新的1000条帖子的链接,如果前一天的帖子数量大于1000,那么前一天的数据可能会收集不完整,可以适当预估这个值来进行调整
    # 如果前一天的贴子数量小于1000条的话，那么程序会自动判断日期,只会抓取前一天的数据,多余的数据将不抓取
    def initialize(path,file,limit=0)
      @path    = path
      @limit   = limit
      @file    = file
      @logger  = Logger.new(STDOUT)
    end

    def get_info
      agent   = get_agent
      links   = get_links(agent)
      results = start_crawl(agent,links)
      return results
    end

    def get_agent
      agent = Mechanize.new
      if File.exist?(@file)
        mtime = File.mtime(@file)
        ntime = Time.now
        dur   = ntime - mtime

        if dur >= 3600 * 24 * 7
          @logger.info '---------cookie 文件超过七天,请重新生成cookie文件 --------'  
          return false
        end
      else
        @logger.info '---------cookie 文件不存在 --------'
        return false
      end
      agent.cookie_jar.load_cookiestxt(@file)
      agent.user_agent_alias = 'Mac Safari'
      return agent  
    end

    def get_links(agent)
      links = []
      if @limit == 0
        uri    = URI::encode(@path)
        page   = agent.get(uri)
        @limit = page.link_with(:text => '尾页').href.split(/pn=/).last.to_i
      end
      0.step(@limit,50).each do |n|
        s1    = Time.now
        uri   = URI::encode(@path)
        if n > 0
          uri = "#{uri}&pn=#{n}"
        end
        page  = agent.get(uri)
        
        lis   = page.search('li.j_thread_list .t_con')
        lis.each do |li|
          begin
            t1         = Time.now
            hash       = Hash.new(0)
            right_list = li.search('.threadlist_li_right')
            link       = right_list.search('.threadlist_lz .threadlist_title a.j_th_tit').attr('href').value
            link       = 'http://tieba.baidu.com' + link
            links      << link
            t2         = Time.now
            @logger.info "---------获取一条链接耗时: #{t2 - t1} 秒   #{link}  ----------"
          rescue
            @logger.info "---------获取链接时出错 已跳过 ------------"
          end
        end
        s2 = Time.now
        @logger.info "************** 链接 #{uri} 获得 #{links.length} 个 url  耗时: #{s2 - s1 } 秒 **************"
      end
      return links
    end

    def start_crawl(agent,links)
      results = []
      focus   = 0
      @logger.info  "^^^^^^^^^^^^^^^^^^^^^^^^  links  #{links.length}  个 "
      links.each do |link|
        begin
          t1             =  Time.now
          hash           =  Hash.new(0)
          page           =  agent.get(link)
          focus          =  page.search('.card_menNum').text
          ag_container   =  page.search('#ag_container')
          unless ag_container.present?
            hash[:title]   =  page.search('.core_title_txt').text.gsub(/\s+/,'')
            hash[:comment] =  page.search('.pb_footer ul.l_posts_num li[2]').search('span[1]').text
            info           =  page.search('#j_p_postlist .l_post:first').attr('data-field').value
            info           =  JSON.parse(info)
            hash[:author]  =  info['author']['user_name']
            hash[:created] =  info['content']['date']
          else
            # 图册精选
            hash[:comment] = page.search('.pb_footer').search('.l_reply_num[2]').search('span[1]').text()
            kw   = @path.split(/kw=/).last.split(/&/).first
            uri  = URI::decode("http://tieba.baidu.com/photo/g/bw/picture/list?kw=#{kw}&alt=jview&rn=200&tid=3077324289&pn=1&ps=161&pe=200&wall_type=v&_=#{Time.now.to_i}")
            page = agent.get(uri)
            json = JSON.parse(page.body)
            hash[:title]   = json['data']['title'].encode('utf-8','gbk')
            hash[:author]  = json['data']['user_name'].encode('utf-8','gbk')
            hash[:created] = Time.at(json['data']['update_time']).strftime('%Y-%m-%d %H:%I:%S')         
          end


          # 如果发表的日期在2014年4月1日之后,则收录该信息,此举是为了获得2014年4月1日以后发表的帖子
          if  Time.parse("#{hash[:created]}") >= Time.parse('2014-04-01 00:00')
            t2             =  Time.now
            results        << hash
            @logger.info hash.inspect
            @logger.info "============>耗时: #{t2 - t1} 秒《=============="          
          else
            @logger.info "****************时间早于 2014-04-01 00:00   results #{results.length} 个*****************"
          end
        rescue
          @logger.info "============> #{link}   出现错误 已跳过 《=============="
          next
        end
      end
      return [focus,results]
    end
  end
end

# tieba = MovieSpider::Tieba.new('http://tieba.baidu.com/f?ie=utf-8&kw=李晨','/Users/x/cookies.txt',6300)
# tieba.get_info

