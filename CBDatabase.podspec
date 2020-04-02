Pod::Spec.new do |s|
  s.name             = 'CBDatabase'
  s.version          = '0.1.0'
  s.summary          = 'A simple wrapper around CoreData'
  s.description      = 'A simple wrapper around CoreData. Developed by Coinbase Wallet team.'

  s.homepage         = 'https://github.com/CoinbaseWallet/Databases'
  s.license          = { :type => "AGPL-3.0-only", :file => 'LICENSE' }
  s.author           = { 'Coinbase' => 'developer@toshi.org' }
  s.source           = { :git => 'https://github.com/CoinbaseWallet/Databases.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/coinbase'

  s.ios.deployment_target = '10.0'
  s.swift_version = '5.0'
  s.source_files = 'ios/Source/**/*.swift'

  s.dependency 'RxCocoa', '>= 4.4.0'
  s.dependency 'RxSwift', '>= 4.4.0'
  s.dependency 'BigInt',  '>= 3.1.0'
end
