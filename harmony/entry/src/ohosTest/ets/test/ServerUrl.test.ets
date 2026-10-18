import { describe, expect, it } from '@ohos/hypium';
import { apiUrl, normalizeServerOrigin } from '../../../main/ets/core/ServerUrl';

export default function serverUrlTest() {
  describe('normalizeServerOrigin', () => {
    it('keeps plain origin', 0, () => {
      expect(normalizeServerOrigin('https://aa.example.com')).assertEqual('https://aa.example.com');
    });
    it('adds https for bare host', 0, () => {
      expect(normalizeServerOrigin('aa.example.com')).assertEqual('https://aa.example.com');
    });
    it('trims trailing slash', 0, () => {
      expect(normalizeServerOrigin('https://aa.example.com/')).assertEqual('https://aa.example.com');
    });
    it('rejects empty', 0, () => {
      expect(normalizeServerOrigin('   ')).assertNull();
    });
    it('builds api url', 0, () => {
      expect(apiUrl('https://aa.example.com', '/sessions')).assertEqual('https://aa.example.com/api/v2/sessions');
    });
  });
}
