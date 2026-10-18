import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { emitter } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppContextHolder } from '../core/AppContextHolder';
import { mobileLoginFromUri, MobileLoginDeepLink, sessionIdFromUri } from '../core/DeepLink';
import { setPendingMobileLogin, setPendingSession } from '../platform/DeepLinkPrefs';

const DOMAIN = 0x0000;
const TAG = 'AgentsAnywhere';

export default class EntryAbility extends UIAbility {
  private pendingSessionId: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContextHolder.init(this.context);
    this.handleWant(want);
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWant(want);
  }

  private handleWant(want: Want): void {
    const uri: string = want.uri === undefined ? '' : want.uri;
    hilog.info(DOMAIN, TAG, 'want uri: %{public}s', uri);
    const mobileLogin: MobileLoginDeepLink | null = mobileLoginFromUri(uri);
    if (mobileLogin !== null) {
      setPendingMobileLogin(mobileLogin.userId, mobileLogin.loginToken, mobileLogin.server);
      emitter.emit({ eventId: 1002 });
      hilog.info(DOMAIN, TAG, 'mobile login deep link applied');
      return;
    }
    const sessionId: string = sessionIdFromUri(uri);
    if (sessionId.length > 0) {
      this.pendingSessionId = sessionId;
      setPendingSession(sessionId);
      emitter.emit({ eventId: 1001 });
      hilog.info(DOMAIN, TAG, 'deep link session: %{public}s', sessionId);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    const storage: LocalStorage = new LocalStorage();
    if (this.pendingSessionId.length > 0) {
      storage.setOrCreate('deeplinkSessionId', this.pendingSessionId);
      hilog.info(DOMAIN, TAG, 'deep link applied before load: %{public}s', this.pendingSessionId);
    }
    windowStage.loadContent('pages/Index', storage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
