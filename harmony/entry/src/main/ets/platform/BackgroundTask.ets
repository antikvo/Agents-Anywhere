import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { AppContextHolder } from '../core/AppContextHolder';

const BUNDLE_NAME: string = 'com.agentsanywhere.harmony';
const ABILITY_NAME: string = 'EntryAbility';

/**
 * 长时任务保活：终端 WebSocket 在后台保持连接。
 * 使用 DATA_TRANSFER 类型；系统会显示「正在运行」通知。
 */
export class BackgroundTask {
  private static running: boolean = false;

  static async start(): Promise<boolean> {
    if (BackgroundTask.running) {
      return true;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME,
          uri: 'agentsanywhere://home'
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: object = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(AppContextHolder.require(),
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent);
      BackgroundTask.running = true;
      return true;
    } catch (error) {
      return false;
    }
  }

  static async stop(): Promise<void> {
    if (!BackgroundTask.running) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(AppContextHolder.require());
    } catch (error) {
      // 忽略停止失败
    } finally {
      BackgroundTask.running = false;
    }
  }

  static isRunning(): boolean {
    return BackgroundTask.running;
  }
}
