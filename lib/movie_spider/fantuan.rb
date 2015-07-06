require 'mechanize'
require 'logger'
module MovieSpider
  class Fantuan
    def initialize
      @logger  = Logger.new(STDOUT)
      @results = []
    end  

    def start_crawl
    	@agent = get_agent
    	get_comment_info
    	return @results
    end	

    def get_comment_info(cursor=0)
    	url  = "http://bar.qq.com/star/10142/post/list?limit=20&flip=1&cursor=#{cursor}&callback=topicList&low_login=1&_=#{Time.now.to_i}"
    	page = get_page(url)
    	if page.present?
      		result = page.body.gsub('topicList(','').gsub('})','}')
      		result = JSON.parse(result) 
      		if result["data"]
      			cursor   = result["data"]["cursor"]
      			hasnext  = cursor['hasnext']
      			nex      = cursor['next']
      			post     = result["data"]["post"]
      			
      			
      			post.each do |po|
      				param    = {}
      				param['postid']      =  po['postid']
      				param['title']       =  po['custom']
      				param['content']     =  po['content']
      				param['orireplynum'] =  po['orireplynum'].to_i
      				param['up']          =  po['up'].to_i
      				param['author']      =  po['userinfo']['nick']
      				param['gender']      =  po['userinfo']['gender'].to_i
      				param['region']      =  po['userinfo']['region'] 
      				param['time']        =  Time.at(po['time'])
      				param['comments']    =  []

      				p1,p2 = po['orireplynum'].to_i.divmod(10)
      				if p2 > 0
      					pg = p1 + 1
      				else
      					pg = p1
      				end 
      				1.upto(pg) do |i|
      					comment = get_reply_info(po['postid'],i)  
      					param['comments'].concat(comment)
      				end    					
      				@results << param
      				@logger.info "#{po['postid']} --- #{param['title']} : 评论量： #{param['comments'].length}"
					    @logger.info "=============================================" 				
      			end
      		end
      		if hasnext.present?
      			get_comment_info(nex)
      		end
    	end
    end

    def get_reply_info(postid,pge)
    	url = "http://bar.qq.com/star/10142/post/#{postid}/timeline/replies?flip=0&limit=10&direct=2&page=#{pge}&callback=mainComment&_=#{Time.now.to_i}"
    	page = get_page(url)
    	comment_arr = []
    	
    	if page.present?
    		result = page.body.gsub('mainComment(','').gsub('})','}')
    		result = JSON.parse(result)
    		if result['data']
    			if result['data']['comment'].present?
    				result['data']['comment'].each do |cmt|
    					comment = {}
    					comment['id'] = cmt['id']
    					comment['time'] = Time.at(cmt['time'].to_i)
    					comment['up'] = cmt['up']
						  comment['rep'] = cmt['rep']
						  comment['content'] = cmt['content']
						  comment['nick'] = cmt['userinfo']['nick']
						  comment['gender'] = cmt['userinfo']['gender']
						  comment['region'] = cmt['userinfo']['region']
						  comment_arr << comment
    				end    			
    			end
    		end
    	end
    	comment_arr
    end

    def get_agent
      @agent = Mechanize.new do |a|
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
      end    	
    end

    def get_page(url)
      page   = nil
      url    = URI.encode(url.to_s.gsub(/\s+/,''))
      begin
        page = @agent.get url
      rescue
        @logger.info  '-------------fantuan get agent.page error start -------------'
        @logger.info  @logger.info "error:#{$!} at:#{$@}"
        @logger.info  '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
        @logger.info  URI.decode(url)
        @logger.info  '-------------fantuan get agent.page error end -------------'
      end
      return page
    end


  end
end