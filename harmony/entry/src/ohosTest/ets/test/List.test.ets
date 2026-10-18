import versionTest from './Version.test';
import serverUrlTest from './ServerUrl.test';
import terminalTest from './Terminal.test';
import markdownTest from './Markdown.test';

export default function testsuite() {
  versionTest();
  serverUrlTest();
  terminalTest();
  markdownTest();
}
