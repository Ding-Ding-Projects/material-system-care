import test from 'node:test';
import assert from 'node:assert/strict';
import {renderArticle,resolveLocal} from '../scripts/articles.mjs';
test('complete article keeps prose and uses internal document routes',()=>{
 const html=renderArticle('# Guide\n\nFull content.\n\n[Next](../next.md#details)', 'docs/topic/readme.md',new Set(['docs/next.md']));
 assert.match(html,/Full content/);assert.match(html,/#\/articles\/docs%2Fnext.md\?heading=details/);
});
test('active HTML and unsafe protocols cannot execute in article body',()=>{
 const html=renderArticle('<script>alert(1)</script><iframe src="https://example.com"></iframe><img src="https://example.com/track" onerror="alert(1)">\n\n[unsafe](javascript:alert(1))','README.md',new Set());
 assert.doesNotMatch(html,/<script|<iframe|onerror|javascript:|src="https:/);
});
test('relative assets stay local and paths cannot escape published sources',()=>{
 assert.equal(resolveLocal('../../../private.png','docs/file.md'),null);
 const html=renderArticle('![Frame](../captures/frame.png)','docs/topic/readme.md',new Set());
 assert.match(html,/src="\.\/source-files\/docs\/captures\/frame.png"/);
});
test('headings are stable and checklist completion is preserved',()=>{
 const html=renderArticle('# A title\n\n## A title\n\n- [x] Complete\n- [ ] Pending','README.md',new Set());
 assert.match(html,/id="a-title"/);assert.match(html,/id="a-title-1"/);assert.equal((html.match(/\schecked=/g)||[]).length,1);
});
