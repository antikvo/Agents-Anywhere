import { AuthMeResponse } from '../../../api/AuthDtos';
import { APP_VERSION } from '../../../core/AppConfig';
import { AuthController } from '../../../feature/auth/AuthController';
import { Notifications } from '../../../platform/Notifications';
import { compareVersions } from '../../../core/Version';
import { AuthApi } from '../../../api/AuthApi';
import { AuthSession } from '../../../feature/auth/AuthSessionStore';

/**
 * 设置页：账号、服务器、版本、外观说明与退出登录。
 * 头像上传、昵称修改、通知设置等后续补齐。
 */
@Component
export struct SettingsScreen {
  session: AuthSession | null = null;
  onBack: () => void = () => {
  };
  onSignOut: () => void = () => {
  };
  onOpenProjects: () => void = () => {
  };
  onProfileUpdated: (name: string) => void = () => {
  };
  private api: AuthApi = new AuthApi();
  private controller: AuthController = new AuthController();
  private notifications: Notifications = new Notifications();
  private authApi: AuthApi = new AuthApi();
  @State checkingUpdate: boolean = false;
  @State updateMessage: string = '';
  @State displayName: string = '';
  @State email: string = '';
  @State role: string = '';
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State message: string = '';
  @State nameOverlay: boolean = false;
  @State nameDraft: string = '';
  @State passwordOverlay: boolean = false;
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State saving: boolean = false;
  @State notificationsEnabled: boolean = false;

  aboutToAppear(): void {
    this.load();
    this.refreshNotificationState();
  }

  private async checkUpdate(): Promise<void> {
    if (this.checkingUpdate) {
      return;
    }
    this.checkingUpdate = true;
    this.updateMessage = '';
    try {
      const session: AuthSession | null = this.session;
      if (session === null) {
        this.updateMessage = '请先登录';
        return;
      }
      const health = await this.authApi.health(session.serverUrl);
      const latestRaw: string | undefined = health.version;
      const latest: string = latestRaw === undefined ? '' : latestRaw.trim();
      const comparison: number | null = compareVersions(latest, APP_VERSION);
      if (comparison === null) {
        this.updateMessage = `无法比较版本：服务端 ${latest} / 客户端 ${APP_VERSION}`;
      } else if (comparison > 0) {
        this.updateMessage = `发现新版本 ${latest}（当前 ${APP_VERSION}）。HarmonyOS 客户端需从源码重新构建安装。`;
      } else {
        this.updateMessage = `已是最新版本（${APP_VERSION}）`;
      }
    } catch (error) {
      this.updateMessage = (error as Error).message;
    } finally {
      this.checkingUpdate = false;
    }
  }

  private async refreshNotificationState(): Promise<void> {
    this.notificationsEnabled = await this.notifications.isEnabled();
  }

  private async enableNotifications(): Promise<void> {
    const enabled: boolean = await this.notifications.requestPermission();
    this.notificationsEnabled = enabled;
    this.message = enabled ? '通知已开启' : '通知未开启，请在系统设置中允许';
  }

  private async testNotification(): Promise<void> {
    await this.notifications.sendTestNotification();
    this.message = '测试通知已发送（下拉通知栏查看）';
  }

  private async load(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      this.loading = false;
      return;
    }
    try {
      const me: AuthMeResponse = await this.api.me(session.serverUrl, session.accessToken);
      const name: string = me.displayName === null || me.displayName === undefined ? '' : me.displayName;
      this.displayName = name.length > 0 ? name : me.userId;
      this.email = me.email === null || me.email === undefined ? '' : me.email;
      this.role = me.role;
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#8A8A8A')
        .width(88)
      Text(value)
        .fontSize(14)
        .fontColor('#111111')
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  private async saveDisplayName(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.saving) {
      return;
    }
    if (this.nameDraft.trim().length === 0) {
      this.errorMessage = '昵称不能为空';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    this.message = '';
    try {
      const me: AuthMeResponse = await this.controller.updateDisplayName(session, this.nameDraft);
      const name: string = me.displayName === null || me.displayName === undefined ?
        this.nameDraft.trim() : me.displayName;
      this.displayName = name;
      this.onProfileUpdated(name);
      this.nameOverlay = false;
      this.message = '昵称已更新';
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.saving = false;
    }
  }

  private async savePassword(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.saving) {
      return;
    }
    if (this.newPassword.length < 8) {
      this.errorMessage = '新密码至少 8 位';
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.errorMessage = '两次输入的密码不一致';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    try {
      await this.controller.changePassword(session, this.newPassword);
      this.passwordOverlay = false;
      this.newPassword = '';
      this.confirmPassword = '';
      this.message = '密码已更新';
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.saving = false;
    }
  }

  build() {
    Stack() {
    Column() {
      Row({ space: 8 }) {
        Button('返回')
          .height(32)
          .fontSize(13)
          .backgroundColor('#F2F2F2')
          .fontColor('#000000')
          .onClick(() => {
            this.onBack();
          })
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.message.length > 0) {
              Text(this.message)
                .fontSize(12)
                .fontColor('#1F7A1F')
                .width('100%')
                .padding({ top: 8, bottom: 4 })
            }

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor('#D93026')
                .width('100%')
                .padding({ top: 8, bottom: 8 })
            }

            Text('账号')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 8 })
            Row() {
              Text('昵称')
                .fontSize(13)
                .fontColor('#8A8A8A')
                .width(88)
              Text(this.displayName)
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Text('修改 ›')
                .fontSize(13)
                .fontColor('#8A8A8A')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.nameDraft = this.displayName;
              this.nameOverlay = true;
            })
            Divider().color('#EFEFEF')
            this.infoRow('邮箱', this.email.length > 0 ? this.email : '未绑定')
            Divider().color('#EFEFEF')
            this.infoRow('角色', this.role)
            Divider().color('#EFEFEF')
            Row() {
              Text('修改密码')
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Text('›')
                .fontSize(14)
                .fontColor('#8A8A8A')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.newPassword = '';
              this.confirmPassword = '';
              this.passwordOverlay = true;
            })

            Text('服务')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 20 })
            this.infoRow('服务器', this.session !== null ? this.session.serverUrl : '—')
            Divider().color('#EFEFEF')
            this.infoRow('版本', APP_VERSION)
            Row({ space: 8 }) {
              Text('检查更新')
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Button(this.checkingUpdate ? '检查中' : '检查')
                .height(26)
                .fontSize(11)
                .backgroundColor('#F2F2F2')
                .fontColor('#111111')
                .enabled(!this.checkingUpdate)
                .onClick(() => {
                  this.checkUpdate();
                })
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
            if (this.updateMessage.length > 0) {
              Text(this.updateMessage)
                .fontSize(11)
                .fontColor('#8A8A8A')
                .width('100%')
                .padding({ bottom: 6 })
            }
            Divider().color('#EFEFEF')
            Row({ space: 8 }) {
              Text('通知')
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Text(this.notificationsEnabled ? '已开启' : '未开启')
                .fontSize(12)
                .fontColor(this.notificationsEnabled ? '#1F7A1F' : '#8A8A8A')
              Button(this.notificationsEnabled ? '测试' : '开启')
                .height(26)
                .fontSize(11)
                .backgroundColor('#F2F2F2')
                .fontColor('#111111')
                .onClick(() => {
                  if (this.notificationsEnabled) {
                    this.testNotification();
                  } else {
                    this.enableNotifications();
                  }
                })
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })

            Text('工作区')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 20 })
            Row() {
              Text('项目')
                .fontSize(14)
                .fontColor('#111111')
                .layoutWeight(1)
              Text('管理 ›')
                .fontSize(13)
                .fontColor('#8A8A8A')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.onOpenProjects();
            })
            Divider().color('#EFEFEF')

            Text('关于')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 20 })
            this.infoRow('客户端', 'Agents Anywhere HarmonyOS')
            this.infoRow('外观', '跟随系统')
            Text('隐私说明：会话内容、时间线与附件可能经过你连接的服务端；自托管时数据由你自己的实例处理。')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
              .padding({ top: 8, bottom: 16 })

            Button('退出登录')
              .width('100%')
              .height(44)
              .backgroundColor('#FDF1F0')
              .fontColor('#D93026')
              .onClick(() => {
                this.onSignOut();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')

      if (this.nameOverlay) {
        Column({ space: 10 }) {
          Text('修改昵称')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          TextInput({ placeholder: '昵称', text: this.nameDraft })
            .height(40)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.nameDraft = value;
            })
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor('#D93026')
              .width('100%')
          }
          Row({ space: 8 }) {
            Button(this.saving ? '保存中…' : '保存')
              .height(34)
              .enabled(!this.saving)
              .onClick(() => {
                this.saveDisplayName();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.nameOverlay = false;
                this.errorMessage = '';
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }

      if (this.passwordOverlay) {
        Column({ space: 10 }) {
          Text('修改密码')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          TextInput({ placeholder: '新密码（至少 8 位）', text: this.newPassword })
            .height(40)
            .fontSize(14)
            .type(InputType.Password)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.newPassword = value;
            })
          TextInput({ placeholder: '再次输入新密码', text: this.confirmPassword })
            .height(40)
            .fontSize(14)
            .type(InputType.Password)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.confirmPassword = value;
            })
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor('#D93026')
              .width('100%')
          }
          Row({ space: 8 }) {
            Button(this.saving ? '保存中…' : '保存')
              .height(34)
              .enabled(!this.saving)
              .onClick(() => {
                this.savePassword();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.passwordOverlay = false;
                this.errorMessage = '';
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
