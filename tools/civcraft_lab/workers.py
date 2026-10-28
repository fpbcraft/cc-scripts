"""Bounded child processes: a stuck match is terminated and recorded, never scored."""
import multiprocessing
import time


def _worker(connection, config):
    from runner import play
    try:
        connection.send(play(config))
    finally:
        connection.close()


def run_bounded(configs, workers):
    context = multiprocessing.get_context('spawn')
    pending, active, results = list(enumerate(configs)), [], [None] * len(configs)
    try:
        while pending or active:
            while pending and len(active) < workers:
                index, config = pending.pop(0)
                receiver, sender = context.Pipe(duplex=False)
                process = context.Process(target=_worker, args=(sender, config))
                process.start()
                sender.close()
                active.append((index, config, process, receiver, time.monotonic()))
            for item in list(active):
                index, config, process, receiver, started = item
                elapsed = time.monotonic() - started
                result = None
                if receiver.poll():
                    try:
                        result = receiver.recv()
                    except EOFError:
                        result = {'config': config, 'status': 'error', 'error': 'worker_eof'}
                elif elapsed > config.get('wallSeconds', 180):
                    process.terminate()
                    result = {'config': config, 'status': 'timeout', 'elapsedSeconds': elapsed,
                              'error': 'match_wall_clock_budget'}
                elif not process.is_alive():
                    result = {'config': config, 'status': 'error',
                              'error': f'worker_exit_{process.exitcode}'}
                if result is not None:
                    process.join(timeout=2)
                    if process.is_alive():
                        process.kill()
                        process.join()
                    receiver.close()
                    results[index] = result
                    active.remove(item)
            if active:
                time.sleep(0.02)
    finally:
        for _, _, process, connection, _ in active:
            if process.is_alive():
                process.terminate()
                process.join(timeout=2)
                if process.is_alive():
                    process.kill()
                    process.join()
            connection.close()
    return results
