#ifndef FLASH_THREAD_POOL_H
#define FLASH_THREAD_POOL_H

// A persistent worker pool for the per-frame parallel loops.
//
// The particle vertex builder used to call `std::thread`'s constructor for
// every chunk of every pass of every frame. Creating and joining a thread costs
// tens of microseconds — on the order of the work being handed to it — so the
// parallel path could easily be slower than the serial one, which is presumably
// why its threshold was set to 100,000 particles and then never reached.
//
// The pool creates its threads once and parks them on a condition variable.
// Dispatching a frame's work is a lock, a counter bump and a notify.
//
// Deliberately minimal: `parallel_for` is synchronous, the calling thread
// participates in the work rather than idling, and there is no queue of
// outstanding jobs. That is all the render path needs, and anything more would
// be untested surface area.

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

namespace flash {

class ThreadPool {
public:
    /// The process-wide pool. Sized once, on first use.
    ///
    /// Intentionally leaked. Joining worker threads during static destruction
    /// is a known way to hang at exit, and a handful of threads parked on a
    /// condition variable cost nothing while idle.
    static ThreadPool& instance() {
        static ThreadPool* pool = new ThreadPool(defaultWorkerCount());
        return *pool;
    }

    /// Number of threads that will run a dispatch, counting the caller.
    int concurrency() const { return (int)workers_.size() + 1; }

    /// Runs `job(i)` for every i in [0, count) and returns once all have
    /// finished. Indices are claimed atomically, so uneven jobs self-balance.
    void parallel_for(int count, const std::function<void(int)>& job) {
        if (count <= 0) return;
        if (workers_.empty() || count == 1) {
            for (int i = 0; i < count; ++i) job(i);
            return;
        }

        {
            std::lock_guard<std::mutex> lock(mutex_);
            job_ = &job;
            jobCount_ = count;
            nextIndex_.store(0, std::memory_order_relaxed);
            pending_ = (int)workers_.size();
            ++generation_;
        }
        startCv_.notify_all();

        // The calling thread is a worker too — it would otherwise block on the
        // condition variable while a core sat idle.
        drain(&job, count);

        std::unique_lock<std::mutex> lock(mutex_);
        doneCv_.wait(lock, [this] { return pending_ == 0; });
        job_ = nullptr;
    }

private:
    explicit ThreadPool(int workerCount) {
        workers_.reserve(workerCount);
        for (int i = 0; i < workerCount; ++i) {
            workers_.emplace_back([this] { workerLoop(); });
        }
    }

    /// One less than the hardware count, because the caller joins in. Capped:
    /// past a handful of threads this workload is memory-bound, and on a phone
    /// the remaining cores are wanted for the platform and raster threads.
    static int defaultWorkerCount() {
        unsigned int hw = std::thread::hardware_concurrency();
        if (hw <= 1) return 0;
        unsigned int workers = hw - 1;
        if (workers > 7) workers = 7;
        return (int)workers;
    }

    void workerLoop() {
        uint64_t seen = 0;
        for (;;) {
            const std::function<void(int)>* job;
            int count;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                startCv_.wait(lock, [this, seen] { return stopping_ || generation_ != seen; });
                if (stopping_) return;
                seen = generation_;
                job = job_;
                count = jobCount_;
            }

            drain(job, count);

            {
                std::lock_guard<std::mutex> lock(mutex_);
                if (--pending_ == 0) doneCv_.notify_one();
            }
        }
    }

    void drain(const std::function<void(int)>* job, int count) {
        for (;;) {
            const int i = nextIndex_.fetch_add(1, std::memory_order_relaxed);
            if (i >= count) return;
            (*job)(i);
        }
    }

    std::vector<std::thread> workers_;
    std::mutex mutex_;
    std::condition_variable startCv_;
    std::condition_variable doneCv_;

    const std::function<void(int)>* job_ = nullptr;
    int jobCount_ = 0;
    std::atomic<int> nextIndex_{0};
    int pending_ = 0;
    uint64_t generation_ = 0;
    bool stopping_ = false;
};

} // namespace flash

#endif // FLASH_THREAD_POOL_H
