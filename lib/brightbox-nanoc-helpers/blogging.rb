module Brightbox
  module Nanoc3
    module Helpers
      # Generates a blog at a subpath and makes available helpers for listing recent posts
      # elsewhere on the site.
      # 
      # You'll need to add a preprocess block to generate the blog:
      # 
      #   preprocess do
      #     generate_blog!
      #   end
      # 
      # And some rules to process the content of the blog and direct the output to the right place
      # 
      #   compile "/posts/*/" do
      #     filter :kramdown
      #     filter :erb
      #   
      #     layout "blog_page"
      #     layout "base"
      #   end
      #   
      #   route "/posts/*" do
      #     # "/posts/2011-01-01-some-title-here" => "/2011/01/01/some-title-here/index.html"
      #     "/blog/#{item.identifier.split("/", 3).last.gsub(/^(\d+)-(\d+)-(\d+)-(.*)$/, '\1/\2/\3/\4')}index.html"
      #   end
      # 
      # And then you need to add your blog posts to ./posts/*.md (given you're using markdown.) They should
      # be named in the format yyyy-mm-dd-slug-of-post.md and it'll automatically pick out the date & slug.
      # 
      module Blogging
        # Make sure we include those modules we need to function
        include ::Nanoc3::Helpers::Tagging
        include ::Nanoc3::Helpers::Blogging
        include ::Nanoc3::Helpers::Rendering
        include Pagination

        GenerateError = Class.new(RuntimeError)

        # We're dealing with posts, not articles
        def posts
          sorted_articles
        end

        # Helper method for the config setting, defaults to 10
        def posts_per_page
          @config[:posts_per_page] || 10
        end

        # Helper method for the config setting, defaults to 10
        def posts_per_feed
          @config[:posts_per_feed] || 10
        end

        # Infer the post's created_at time from the filename for the specified post
        def extract_post_created_at post
          post.identifier[%r{/(\d+-\d+-\d+)[\w-]+/?$}, 1]
        end

        # Takes in "hello-world", outputs "Hello World"
        # Override by specifying "title: Hello World!" in the post's metadata
        def extract_post_title post
          post.identifier[%r{/(\d+-\d+-\d+)([\w-]+)/?$}, 2].split("-").map(&:capitalize).join(" ")
        end

        # Override Blogging#articles to select items in /post, rather than of kind article.
        # Also makes sure the kind defaults to "article" and created_at defaults to being extracted
        # from the filename, rather than having to specify both in the metadata.
        def articles
          posts = @items.select {|item| item.identifier =~ %r{^/post} }
          # Setup some things that the Blogging module expect
          posts.each do |item|
            item[:kind] ||= "article"
            item[:created_at] ||= extract_post_created_at(item)
            item[:title] ||= extract_post_title(item)
          end
          posts
        end

        # Get the last x posts, where x defaults to 5.
        def recent_posts count=5
          posts[0...count].dup
        end

        # Returns an array of monthly archive objects in descending date objects. Only includes a month/year if it has posts
        # therein. Use #to_s for the pretty name (eg. "November 2011") and #to_path for the URL path (eg. "/blog/2011/")
        def monthly_archives
          ma = Struct.new(:year, :month) do
            def to_s
              "#{Date::MONTHNAMES[month]} #{year}"
            end

            def to_path
              "/blog/#{year}/#{"%.2d" % month}/"
            end
          end
          monthly_posts.inject({}) do |hash, (year, months)|
            hash[year] = months.keys
            hash
          end.map { |year, months| months.map { |month| ma.new(year, month) } }.flatten.sort_by {|e| [e.year, e.month] }.reverse
        end

        def monthly_posts
          # Turn the array of posts into nested hashes of year and months, containing the posts therein that year/month
          @monthly_posts ||= posts.inject({}) do |hash, post|
            year, month = attribute_to_time(post[:created_at]).strftime("%Y %m").split.map(&:to_i)
            hash[year] ||= {}
            hash[year][month] ||= []
            hash[year][month] << post
            hash
          end
        end

        # The main method to kick everything off.
        # Generates the archive, monthly archives and author archives
        # Expects the items in /posts to be named `yyyy-mm-dd-title` - like jekyll
        def generate_blog!
          raise GenerateError, "no blog posts found in ./content/posts/" unless posts && posts.count > 0

          generate_blog_archive
          generate_monthly_archives
          generate_author_archives
          generate_tag_archives
        end

        # Generates /blog(/page/:i)/ pages, listing posts on as many pages as are needed
        def generate_blog_archive
          page_title = "Latest"
          paginate_posts_at "/blog/", posts, page_title
          atom_feed_at "/blog/feed/", posts, page_title
        end

        # Generates /blog/:year/:month(/page/:i)/ pages, listing posts in each month on as many pages as needed
        def generate_monthly_archives
          # Run through years & months in order, generating paginated pages for each
          monthly_posts.keys.sort.each do |year|
            monthly_posts[year].keys.sort.each do |month|
              paginate_posts_at("/blog/#{year}/#{"%.2d" % month}/", monthly_posts[year][month], "Posts from #{Date::MONTHNAMES[month]} #{year}")
            end
          end
        end

        # Generates /blog/author/:name(/page/:i)/ pages, listing posts by each author on as many pages as needed
        def generate_author_archives
          posts_by_authors = posts.inject({}) do |hash, post|
            author = post[:author] || raise(GenerateError, "post #{post.identifier} has no author set")
            hash[author] ||= []
            hash[author] << post
            hash
          end

          posts_by_authors.each do |author, author_posts|
            page_title = "Posts by #{author}"
            paginate_posts_at "/blog/author/#{slugify(author)}", author_posts, page_title
            atom_feed_at "/blog/author/#{slugify(author)}/feed/", author_posts, page_title
          end
        end

        def all_post_tags
          posts.map {|i| i[:tags] }.flatten.compact.uniq
        end

        def generate_tag_archives
          all_post_tags.each do |tag|
            page_title = "Posts with tag \"#{tag}\""
            paginate_posts_at "/blog/tag/#{slugify(tag)}", posts_with_tag(tag), page_title
            atom_feed_at "/blog/tag/#{slugify(tag)}/feed/", posts_with_tag(tag), page_title
          end
        end

        def posts_with_tag tag
          posts.select {|post| post[:tags] && post[:tags].include?(tag) }
        end

        def tags_for_post post, params={}
          params ||= {}
          params[:separator]  ||= ", "
          params[:base_url]   ||= "http://technorati.com/tag/"
          params[:none_text]  ||= "(none)"

          if post[:tags] && !post[:tags].empty?
            post[:tags].map {|tag| link_for_post_tag(tag, params[:base_url]) }.join(params[:separator])
          else
            params[:none_text]
          end
        end

        def link_for_post_tag name, base_uri
          %{<a href="#{h base_uri}#{h slugify(name)}" rel="tag">#{h name}</a>}
        end

        def slugify str
          str.downcase.gsub(/\s+/, "-").gsub(/-{2,}/, "-")
        end

        # path is expected to be a string
        # page_title can be a String or Lambda. Lambda takes one argument, current page number
        def paginate_posts_at path, posts, page_title="Blog"
          # Make sure path starts/ends with forward slash
          path = "/#{path[%r{\A/?(.+?)/?\z}, 1]}/"
          # Split the entire list of articles in a list of sub-lists
          post_pages = posts.each_slice(posts_per_page).to_a

          # Generate a Nanoc3::Item for each of these pages
          post_pages.each_with_index do |subarticles, i|
            page_num = i + 1

            @items << ::Nanoc3::Item.new(
              # @item.attributes is a bit of a hack, but it passes through whatever we pass as attributes
              # here to the blog_archive template, which is where we actually consume them.
              %{<%= render "blog_archive", @item.attributes %>},
              {
                :title => (page_title.is_a?(String) ? page_title : page_title[page_num] ),
                :page_number => page_num,
                :next_page => post_pages[page_num] != nil,
                :pagination_path => path,
                :posts => subarticles,
              },
              # First page is at /blog, every page thereafter at /blog/page/:i
              (page_num == 1 ? path : "#{path}page/#{page_num}/")
            )
          end
        end

        # Generate atom feed
        # path and page_title are expected to be strings
        def atom_feed_at path, posts, feed_title="Blog"
          @items << ::Nanoc3::Item.new(
            %{<%= atom_feed :title => @item[:title], :articles => @item[:posts], :limit => posts_per_feed %>},
            {
              :posts => posts,
              :title => @config[:feed_title] ? "#{@config[:feed_title]} - #{feed_title}" : feed_title
            },
            path
          )
        end
      end
    end
  end
end
