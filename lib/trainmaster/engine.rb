Gem.loaded_specs['trainmaster'].dependencies.each do |d|
 require d.name
end

module Trainmaster
  class Engine < ::Rails::Engine
    isolate_namespace Trainmaster
  end
end
