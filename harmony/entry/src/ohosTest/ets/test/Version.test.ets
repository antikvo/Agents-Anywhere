import { describe, expect, it } from '@ohos/hypium';
import { compareVersions } from '../../../main/ets/core/Version';

export default function versionTest() {
  describe('compareVersions', () => {
    it('equal versions', 0, () => {
      expect(compareVersions('2.1.0', '2.1.0')).assertEqual(0);
    });
    it('newer major', 0, () => {
      expect(compareVersions('3.0.0', '2.9.9')).assertEqual(1);
    });
    it('older patch', 0, () => {
      expect(compareVersions('2.1.0', '2.1.1')).assertEqual(-1);
    });
    it('different lengths', 0, () => {
      expect(compareVersions('2.1', '2.1.0')).assertEqual(0);
    });
    it('empty input is invalid', 0, () => {
      expect(compareVersions('', '2.1.0')).assertNull();
    });
  });
}
