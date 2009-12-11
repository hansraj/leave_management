ActionController::Routing::Routes.draw do |map|
    map.resources :leaves, :as => :leave_management, :member => {:print => :get}
end
