import { AuthMeResponse } from '../api/AuthDtos';
import { AuthController } from '../feature/auth/AuthController';
import { AuthSession } from '../feature/auth/AuthSessionStore';
import { SessionItem } from '../model/Session';
import { LoginScreen } from '../ui/screens/auth/LoginScreen';
import { SessionListScreen } from '../ui/screens/home/SessionListScreen';
import { SessionDetailScreen } from '../ui/screens/sessiondetail/SessionDetailScreen';
import { SettingsScreen } from '../ui/screens/profile/SettingsScreen';
import { ProjectsScreen } from '../ui/screens/projects/ProjectsScreen';
import { takePendingSession } from '../platform/DeepLinkPrefs';
import { emitter } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  private controller: AuthController = new AuthController();
  @State session: AuthSession | null = null;
  @State loading: boolean = true;
  @State accountLabel: string = '';
  @State selectedSession: SessionItem | null = null;
  @State showSettings: boolean = false;
  @State showProjects: boolean = false;
  @State pendingDeepLink: string = '';
  @LocalStorageProp('deeplinkSessionId') @Watch('onDeepLinkChanged') deepLinkSessionId: string = '';

  aboutToAppear(): void {
    this.consumeDeepLink();
    emitter.on({ eventId: 1001 }, () => {
      this.consumeDeepLink();
    });
    this.restoreSession();
  }

  aboutToDisappear(): void {
    emitter.off(1001);
  }

  onPageShow(): void {
    AppStorage.setOrCreate('appForeground', true);
    this.consumeDeepLink();
  }

  onPageHide(): void {
    AppStorage.setOrCreate('appForeground', false);
  }

  private async consumeDeepLink(): Promise<void> {
    let target: string = await takePendingSession();
    let attempt: number = 0;
    while (target.length === 0 && attempt < 4) {
      attempt++;
      await new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 150);
      });
      target = await takePendingSession();
    }
    if (target.length > 0) {
      this.pendingDeepLink = target;
      this.selectedSession = null;
      this.showSettings = false;
      this.showProjects = false;
    }
  }

  onDeepLinkChanged(): void {
    this.consumeDeepLink();
  }

  private async restoreSession(): Promise<void> {
    try {
      const session: AuthSession | null = await this.controller.restore();
      this.session = session;
      if (session !== null) {
        this.accountLabel = this.labelOf(session);
        await this.loadAccount(session);
      }
    } finally {
      this.loading = false;
    }
  }

  private labelOf(session: AuthSession): string {
    const name: string = session.displayName === null || session.displayName === undefined ?
      '' : session.displayName;
    if (name.length > 0) {
      return name;
    }
    const email: string = session.email === null || session.email === undefined ? '' : session.email;
    return email.length > 0 ? email : session.userId;
  }

  private async loadAccount(session: AuthSession): Promise<void> {
    try {
      const me: AuthMeResponse = await this.controller.me(session);
      this.accountLabel = me.displayName !== undefined && me.displayName.length > 0 ?
        me.displayName : (me.email !== undefined ? me.email : me.userId);
    } catch (error) {
      // 会话可能过期：保留登录态，由后续请求的 401 统一处理
      this.accountLabel = session.userId;
    }
  }

  private async signOut(): Promise<void> {
    await this.controller.signOut();
    this.session = null;
    this.accountLabel = '';
    this.selectedSession = null;
    this.showSettings = false;
    this.showProjects = false;
  }

  build() {
    Stack() {
      if (this.loading) {
        LoadingProgress()
          .width(48)
          .height(48)
      } else if (this.session === null) {
        LoginScreen({
          controller: this.controller,
          onSignedIn: (session: AuthSession) => {
            this.session = session;
            this.accountLabel = this.labelOf(session);
            this.loadAccount(session);
          }
        })
      } else if (this.showProjects) {
        ProjectsScreen({
          session: this.session,
          onBack: () => {
            this.showProjects = false;
          }
        })
      } else if (this.showSettings) {
        SettingsScreen({
          session: this.session,
          onBack: () => {
            this.showSettings = false;
          },
          onSignOut: () => {
            this.signOut();
          },
          onOpenProjects: () => {
            this.showProjects = true;
          },
          onProfileUpdated: (name: string) => {
            this.accountLabel = name;
            const current: AuthSession | null = this.session;
            if (current !== null) {
              current.displayName = name;
              this.session = current;
            }
            this.controller.persistDisplayName(name);
          }
        })
      } else if (this.selectedSession !== null) {
        SessionDetailScreen({
          session: this.session,
          initial: this.selectedSession,
          onBack: () => {
            this.selectedSession = null;
          }
        })
      } else {
        SessionListScreen({
          session: this.session,
          accountLabel: this.accountLabel,
          onSignOut: () => {
            this.signOut();
          },
          pendingDeepLink: this.pendingDeepLink,
          onDeepLinkConsumed: () => {
            this.pendingDeepLink = '';
          },
          onOpenSession: (item: SessionItem) => {
            this.selectedSession = item;
          },
          onOpenSettings: () => {
            this.showSettings = true;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
