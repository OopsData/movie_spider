#require 'micro_spider'
require 'mechanize'
require 'logger'
require 'open-uri'
module MovieSpider
  class Tieba
    # path 贴吧主页地址
    # file 表示从firefox导出的cookie.txt文件的绝对路径
    # limit 表示要抓取的pn值,这个pn指的是每次翻页的时候改变的那个pn值
    # limit 值约大,表示抓取数据的时间距离今天越远
    # 比如说1000,那么只收集最活跃的1000条帖子的链接
    def initialize(name,path,file,limit=nil)
      @name    = name
      @path    = path
      @agent   = nil
      @limit   = limit
      @file    = file
      @logger  = Logger.new(STDOUT)
      @results = {}
    end


    def start_crawl
      @agent = get_agent
      page   = nil
      p "start crawl"
      begin
        begin 
          page = @agent.get(@path) 
          p page 
        rescue
        end
      end while page.nil?
      if page.present?
        get_post_info(page)
        begin 
          focus  = get_focus(page)
        rescue
          focus  = 0
        end
      end
      return @results
    end

    def get_focus(page)
      focus = page.search('.j_post_num')[0].text().scan(/\d+/).join('').to_i
    end

    def get_post_info_extend(url)
      doc = Nokogiri::HTML(open(url))
      doc.css("#thread_list .j_thread_list .threadlist_title a").each do |link|
        get_detail('http://tieba.baidu.com' + link.attr('href'))
        @logger.info '----complete one theme----'
      end
      next_page = doc.css('#frs_list_pager a.next')
      if next_page && next_page.length > 0 
        begin 
          link = next_page.attr('href').value
        rescue
          @logger.info next_page
        end
        #@logger.info '----complete one page----'
        get_post_info_extend(link)
      end
    end

    def get_post_info(page)
      cpn = page.uri.request_uri.to_s.split('pn=').last
      thread_list = page.search("#thread_list")
      if thread_list.length > 0 
        page.search("#thread_list .j_thread_list .threadlist_title a").each do |link|
          if link 
            link =  "http://tieba.baidu.com" + link.attr('href')
            get_detail(link)
          end
        end
        #@logger.info "**********************************  #{@name} 完成第 #{cpn} 个主题的抓取  **********************************"
        puts "**********************************  #{@name} 完成第 #{cpn} 个主题的抓取  **********************************"
        next_page = page.link_with(:text => '下一页>')
        if next_page
          link    = next_page.href
          link    = 'http://tieba.baidu.com' + link
          pn      = link.to_s.split('pn=').last.to_i
          page    = nil
  
          begin
            begin
              page  = @agent.get(link) 
            rescue
            end
          end while page.nil?
  
          if page
            if @limit 
              if pn   <= @limit
                get_post_info(page)
              end        
            else
              get_post_info(page)
            end
          end
        end 
      else
        get_post_info_extend(page.uri.to_s)
      end     
    end

    def get_detail(link)
      link = link.match('http') ? link : 'http://tieba.baidu.com' + link
      tid     = link.to_s.split('/p/').last
      if tid.include?('?pn=')
        tid   = tid.split('?pn=').first
      end
      page    = nil
      begin
        begin
          page  = @agent.get(link)  
        rescue
        end
      end while page.nil? 

      if page.present?
        page404 = page.search('body.page404')
        unless  page404.present?
          posts  = [] # 盛放每页的post用
          begin 
            title  = page.search(".core_title_txt").attr('title').value
          rescue
            title  = '' # 没有标题，可能是图片贴
          end
          
          
          reply  = page.search(".pb_footer .l_posts_num:first .l_reply_num .red:first").text
          basic  = {} # 盛放主题帖基本信息
          posts  = [] # 盛放跟帖信息
          page.search(".l_post").each do |post|
            begin
              info     = JSON.parse(post.attr('data-field'))
            rescue
              next
            end

            cont     = post.search(".d_post_content_main .d_post_content").text
            #cont     = post.search(".d_post_content_main .d_post_content").text.strip!
            date     = info['content']['date']
            date     = post.search('.post-tail-wrap span.tail-info:last').text unless date.present?
            post_id  = info['content']['post_id']
            date     = date.present? ? date.split(' ').first : ''
            if info['content']['post_no'] == 1
              #主题帖
              basic[:author]        = {}
              basic[:title]         = title
              basic[:content]       = cont
              basic[:date]          = date
              basic[:reply]         = reply
              basic[:author][:name] = info["author"]["user_name"]
              # basic[:author][:sex]  = info['author']['user_sex'] == 2 ? '女' : '男'
              # basic[:author][:level_id]   =  info["author"]["level_id"]
              # basic[:author][:level_name] =  info["author"]["level_name"]
            else
              #回复主题帖
              reply_info = {}
              reply_info[:post_id]     = post_id
              reply_info[:author]      = info["author"]["user_name"] # 回复的作者
              reply_info[:content]     = cont #回复的内容
              reply_info[:comment_num] = info['content']['comment_num'] # 该回复的评论数
              reply_info[:date]        = date #回复的时间
  
              # 回复贴的评论
              if reply_info[:comment_num].to_i > 0 
                pid      = post_id
                pg,rem   = reply_info[:comment_num].to_i.divmod(10)
  
                if rem > 0 
                  pg = pg + 1
                else
                  pg = pg
                end
  
                cmts = []
                1.upto(pg) do |pn|
                  res  = get_cmts(tid,pid,pn)
                  cmts << res  if res.length > 0 
                end
                cmts.flatten!
                reply_info[:comments] = cmts
              end
              posts << reply_info
            end
          end
  
          unless @results["#{tid}"].present?
            @results["#{tid}"]         = {}
            @results["#{tid}"][:basic] =  basic
            @results["#{tid}"][:posts] = []
          end
          @results["#{tid}"][:posts]   << posts
          @results["#{tid}"][:posts].flatten!        
        end
        # puts @results.inspect 
        #@logger.info '-------------------'
        next_page = page.link_with(:text => '下一页')
        if next_page
          get_detail(next_page.href)
        end 
      end
    end

    def get_cmts(tid,pid,pn)
      url      = "http://tieba.baidu.com/p/comment?tid=#{tid}&pid=#{pid}&pn=#{pn}&t=#{Time.now.to_i}"
      page     = nil
      begin
        begin
          page = @agent.get(url)
        rescue
        end
      end while page.nil?
      
      cnt_arr = []
      if page.present?
        page.search(".lzl_single_post").each do |post|
          inf      = JSON.parse(post.attr('data-field'))
          cmt_id   = inf['spid']
          cnt      = post.search('.lzl_cnt')
          cnt_hash = {}
          cnt_hash[:cmt_id]  = cmt_id
          cnt_hash[:author]  = cnt.search("a.j_user_card").text
          cnt_hash[:content] = cnt.search(".lzl_content_main").text.strip!
          date               = cnt.search(".lzl_time").text
          if date.present?
            date = date.split(' ').first
          else
            date = ''
          end
          cnt_hash[:date]    = date
          cnt_arr << cnt_hash
        end
      end
      return cnt_arr
    end

    def get_agent
      agent = Mechanize.new do |a| 
        a.follow_meta_refresh = true
        a.keep_alive = false
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
        a.gzip_enabled = false
      end
      agent.cookie_jar.load_cookiestxt(@file)
      agent.user_agent_alias = 'Mac Safari'
      return agent  
    end
  end
end

