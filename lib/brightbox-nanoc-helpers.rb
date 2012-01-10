require "brightbox-nanoc-helpers/version"

module Brightbox
  module Nanoc3
    module Helpers
      autoload :Blogging, "brightbox-nanoc-helpers/blogging"
      autoload :Pagination, "brightbox-nanoc-helpers/pagination"
    end
  end
end

# load this for usage if required
require "brightbox-nanoc-helpers/static_datasource"
