import Foundation

/// Retains each bucket's min/max in original order plus endpoints. Summary uses unsampled rows.
public enum TrendSampler {
    public static func indices(values: [Int64], maximumPoints: Int = 500) -> [Int] {
        guard values.count > maximumPoints, maximumPoints >= 4 else { return Array(values.indices) }
        let buckets = max(1,(maximumPoints-2)/2), interior = values.count-2
        var result = Set<Int>([0,values.count-1])
        for bucket in 0..<buckets {
            let start = 1+bucket*interior/buckets, end = 1+(bucket+1)*interior/buckets
            guard start < end else { continue }
            var low = start, high = start
            for i in start..<end { if values[i] < values[low] { low = i }; if values[i] > values[high] { high = i } }
            result.insert(low); result.insert(high)
        }
        return result.sorted()
    }
}
