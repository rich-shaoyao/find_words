platform :ios, '17.2' # 与工程 IPHONEOS_DEPLOYMENT_TARGET 保持一致
use_frameworks!

target 'flip_chess' do
  # AdMob (Google Mobile Ads SDK) — 版本精确锁定 11.7.0
  pod 'Google-Mobile-Ads-SDK', '= 11.7.0'

  # Meta Audience Network
  pod 'FBAudienceNetwork'

  # Liftoff (Vungle SDK)
  pod 'VungleSDK-iOS'

  # Chartboost
  pod 'ChartboostSDK'

  # InMobi
  pod 'InMobiSDK'

  # Unity Ads
  pod 'UnityAds'
end

# Pods 的 target（Pods-flip_chess 以及各 SDK 的 framework）不参与签名。
#
# 原因：CI 在 xcodebuild 命令行里**全局**传了 PROVISIONING_PROFILE_SPECIFIER，这个值会作用到
# 所有 target（含 Pods 里的），而 framework target 不支持 provisioning profile，archive 阶段
# 会直接报 "does not support provisioning profiles ... but provisioning profile has been
# manually specified"。Pods 的 framework 自身也不需要描述文件 —— 嵌入 App 时由主 target 的
# `[CP] Embed Pods Frameworks` 用 App 的签名身份重新签名。
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
    end
  end
end
