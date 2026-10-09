/** Every evaluation owns a disposable worker, a size budget, and a deadline. */
export function matchInWorker(pattern, flags, texts, timeout = 150) {
  if (pattern.length > 256 || texts.length > 4096 || texts.some(x => x.length > 4096) || !/^[imsu]*$/.test(flags) || new Set(flags).size !== flags.length) return Promise.reject(new Error('Search limits exceeded.'));
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL('./search-worker.mjs', import.meta.url), {type:'module'});
    const timer = setTimeout(() => {worker.terminate(); reject(new Error('Pattern exceeded the search deadline.'));}, timeout);
    const finish = () => {clearTimeout(timer); worker.terminate();};
    worker.onmessage = ({data}) => {finish(); data.error ? reject(new Error('Invalid regular expression.')) : resolve(data.matches);};
    worker.onerror = () => {finish(); reject(new Error('Search worker unavailable.'));};
    worker.postMessage({pattern, flags, texts});
  });
}
