Pod::Spec.new do |s|
  s.name             = 'Databases'
  s.version          = '0.1.0'
  s.summary          = 'A simple wrapper around CoreData'
  s.description      = s.summary

  s.homepage         = 'https://github.com/CoinbaseWallet/Databases'
  s.license          = { :type => "AGPL-3.0-only", :file => 'LICENSE' }
  s.author           = { 'Coinbase' => 'developer@toshi.org' }
  s.source           = { :git => 'https://github.com/CoinbaseWallet/Databases.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/coinbase'

  s.ios.deployment_target = '11.0'
  s.swift_version = '4.2'
  s.source_files = 'Databases/**/*'

  s.dependency 'RxSwift', '~> 4.3.0'
  s.dependency 'RxCocoa', '~> 4.3.0'
end
