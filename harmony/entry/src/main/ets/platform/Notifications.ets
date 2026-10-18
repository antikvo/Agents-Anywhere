import { notificationManager } from '@kit.NotificationKit';
import { wantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../core/AppContextHolder';

const BUNDLE_NAME: string = 'com.agentsanywhere.harmony';
const ABILITY_NAME: string = 'EntryAbility';

/**
 * 本地通知：审批/新消息到达时提醒，点击后通过深链打开会话。
 * Push Kit 远程推送需要 AGC 配置，首版先做本地通知。
 */
export class Notifications {
  async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      return false;
    }
  }

  async requestPermission(): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        return true;
      }
      await notificationManager.requestEnableNotification(AppContextHolder.require());
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      return false;
    }
  }

  async notifySession(sessionId: string, title: string, text: string): Promise<void> {
    if (sessionId.length === 0) {
      return;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME,
          uri: `agentsanywhere://session/${sessionId}`
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: object = await wantAgent.getWantAgent(info);
      const request: notificationManager.NotificationRequest = {
        id: this.notificationId(sessionId),
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
            additionalText: 'Agents Anywhere'
          }
        },
        wantAgent: agent
      };
      await notificationManager.publish(request);
    } catch (error) {
      // 通知失败不应影响主流程
    }
  }

  async sendTestNotification(): Promise<void> {
    await this.requestPermission();
    await this.notifySession('ses_test_1', 'Agents Anywhere 测试通知', '点击可直接打开会话，验证深链跳转。');
  }

  private notificationId(sessionId: string): number {
    let hash: number = 0;
    for (let i = 0; i < sessionId.length; i++) {
      hash = (hash * 31 + sessionId.charCodeAt(i)) & 0x7fffffff;
    }
    return hash;
  }
}
