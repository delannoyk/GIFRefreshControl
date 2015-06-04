Pod::Spec.new do |s|
  s.name         = 'GIFRefreshControl'
  s.version      = '1.1.0'
  s.license      =  { :type => 'MIT' }
  s.homepage     = 'https://github.com/delannoyk/GIFRefreshControl'
  s.authors      = {
    'Kevin Delannoy' => 'delannoyk@gmail.com'
  }
  s.summary      = 'GIFRefreshControl is a pull to refresh that supports GIF images as track animations.'

# Source Info
  s.platform     =  :ios, '8.0'
  s.source       =  {
    :git => 'https://github.com/delannoyk/GIFRefreshControl.git',
    :tag => s.version.to_s
  }
  s.source_files = 'GIFRefreshControl.swift'
  s.framework    =  'UIKit', 'ImageIO'

  s.requires_arc = true
end
