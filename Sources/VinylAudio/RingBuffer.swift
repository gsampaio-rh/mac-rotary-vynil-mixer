import Darwin

final class AudioRingBuffer {
    private let storage: UnsafeMutablePointer<Float>
    private let capacity: Int
    private var writeHead: Int = 0
    private var readHead: Int = 0
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>

    init(capacity: Int) {
        self.capacity = capacity
        storage = .allocate(capacity: capacity)
        storage.initialize(repeating: 0, count: capacity)
        mutex = .allocate(capacity: 1)
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deallocate()
        storage.deinitialize(count: capacity)
        storage.deallocate()
    }

    func write(_ source: UnsafePointer<Float>, count: Int) {
        pthread_mutex_lock(mutex)
        for i in 0..<count {
            storage[writeHead] = source[i]
            writeHead = (writeHead + 1) % capacity
        }
        pthread_mutex_unlock(mutex)
    }

    func read(_ dest: UnsafeMutablePointer<Float>, count: Int) {
        pthread_mutex_lock(mutex)
        let w = writeHead
        let r = readHead
        let avail = w >= r ? w - r : capacity - r + w
        let readable = min(count, avail)
        for i in 0..<readable {
            dest[i] = storage[(r + i) % capacity]
        }
        readHead = (r + readable) % capacity
        pthread_mutex_unlock(mutex)
        if readable < count {
            for i in readable..<count { dest[i] = 0 }
        }
    }

    func reset() {
        pthread_mutex_lock(mutex)
        writeHead = 0
        readHead = 0
        pthread_mutex_unlock(mutex)
    }
}
