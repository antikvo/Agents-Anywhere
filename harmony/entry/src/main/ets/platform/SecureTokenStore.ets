import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';

function bytesOf(value: string): Uint8Array {
  return new util.TextEncoder().encodeInto(value);
}

function stringOf(bytes: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

/**
 * 用 Asset Store Kit 加密保存访问令牌。
 * 失败时返回 false，调用方回退到 preferences（与 Android 现状一致）。
 */
export class SecureTokenStore {
  private aliasFor(key: string): Uint8Array {
    return bytesOf(`agentsanywhere.token.${key}`);
  }

  async save(key: string, token: string): Promise<boolean> {
    const alias: Uint8Array = this.aliasFor(key);
    const attrs: asset.AssetMap = new Map();
    attrs.set(asset.Tag.ALIAS, alias);
    attrs.set(asset.Tag.SECRET, bytesOf(token));
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    try {
      await asset.remove(attrs);
    } catch (error) {
      // 不存在时忽略
    }
    try {
      await asset.add(attrs);
      return true;
    } catch (error) {
      return false;
    }
  }

  async load(key: string): Promise<string> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.aliasFor(key));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: Array<asset.AssetMap> = await asset.query(query);
      if (results.length === 0) {
        return '';
      }
      const secret = results[0].get(asset.Tag.SECRET);
      if (secret === undefined || secret === null) {
        return '';
      }
      return stringOf(secret as Uint8Array);
    } catch (error) {
      return '';
    }
  }

  async clear(key: string): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.aliasFor(key));
    try {
      await asset.remove(query);
    } catch (error) {
      // 忽略不存在
    }
  }
}
