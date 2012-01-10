module Brightbox
  module Nanoc3
    module Helpers
      # This is originally from http://groups.google.com/group/nanoc/msg/5685346a119c8693?pli=1
      # 
      # Some example rules you'll want:
      # 
      #   route '/static/*' do
      #     # /static/foo.html/ → /foo.html
      #     item.identifier[7..-2]
      #   end
      #
      #   compile '/static/*' do
      #   end
      # 
      # And example datasource for config.yml:
      # 
      #   data_sources:
      #   -
      #     type: static
      #     items_root: /static/
      # 
      class StaticDatasource < ::Nanoc3::DataSource
        identifier :static

        def items
          # Get prefix
          prefix = config[:prefix] || 'static'

          # Get all files under prefix dir
          filenames = Dir[prefix + '/**/*'].select { |f| File.file?(f) }

          # Convert filenames to items
          filenames.map do |filename|
            attributes = {
              :extension => File.extname(filename)[1..-1],
              :filename  => filename,
            }
            identifier = filename[(prefix.length+1)..-1] + '/'

            mtime      = File.mtime(filename)
            checksum   = checksum_for(filename)

            ::Nanoc3::Item.new(
              filename,
              attributes,
              identifier,
              :binary => true, :mtime => mtime, :checksum => checksum
            )
          end
        end

      private

        # Returns a checksum of the given filenames
        # TODO un-duplicate this somewhere
        def checksum_for(*filenames)
          filenames.flatten.map do |filename|
            digest = Digest::SHA1.new
            File.open(filename, 'r') do |io|
              until io.eof
                data = io.readpartial(2**10)
                digest.update(data)
              end
            end
            digest.hexdigest
          end.join('-')
        end
      end
    end

  end
end
