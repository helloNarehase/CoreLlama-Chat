//
//  CoreBPE.swift
//  Don-Quixote
//
//  Created by 하늘 on 10/20/24.
//

import Foundation

// BPETokenizer class that implements byte-pair encoding (BPE)
class BPETokenizer {
    var ranks: [Data: Int]  // Mapping of byte-pair ranks
    var vocab: [Data: Int]  // Vocabulary of tokens including special tokens
    var specialTokens: [String: Int]  // Mapping of special tokens to their IDs
    var pattern: NSRegularExpression!  // Regular expression to match text tokens
    private let patternStr: String = #"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"#
    var reverseVocab: [Int: Data]  // Reverse mapping of token IDs to byte sequences (for decoding)
    
    // Constructor for initializing the tokenizer with ranks and special tokens
    init(mergeableRanks: [Data: Int], specialTokens: [String: Int]) {
        self.ranks = mergeableRanks
        self.vocab = mergeableRanks
        self.specialTokens = specialTokens
        self.reverseVocab = [:]
        
        // Add special tokens to the vocabulary with unique IDs
        for (idx, token) in specialTokens.keys.enumerated() {
            let tokenData = token.data(using: .utf8)!
            let tokenID = vocab.count + idx + 1
            self.vocab[tokenData] = tokenID
            self.reverseVocab[tokenID] = tokenData
        }
        
        // Create reverse lookup for mergeable ranks as well
        for (bytePair, id) in mergeableRanks {
            self.reverseVocab[id] = bytePair
        }
        
        // Compile the regular expression pattern for tokenization
        do {
            self.pattern = try NSRegularExpression(pattern: patternStr, options: [])
        } catch {
            print("Invalid regex pattern")
        }
    }
    
    // Find all tokens in the input text using the regex pattern
    func findAll(_ text: String) -> [String] {
        let nsText = text as NSString
        let matches = self.pattern.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.map { nsText.substring(with: $0.range) }
    }
    
    // Split the text based on special tokens, returning segments with a flag indicating if it is a special token
    func splitBySpecialTokens(_ text: String) -> [(String, Bool)] {
        // Sort special tokens by length to prevent partial matching
        let sortedSpecialTokens = specialTokens.keys.sorted { $0.count > $1.count }
        let tokenPattern = sortedSpecialTokens.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let tokenRegex = try! NSRegularExpression(pattern: tokenPattern, options: [])
        
        var segments: [(String, Bool)] = []
        var lastPos = 0
        let nsText = text as NSString
        
        // Match and extract special tokens
        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            if match.range.location > lastPos {
                segments.append((nsText.substring(with: NSRange(location: lastPos, length: match.range.location - lastPos)), false))
            }
            segments.append((nsText.substring(with: match.range), true))
            lastPos = match.range.location + match.range.length
        }
        
        // Append remaining text
        if lastPos < nsText.length {
            segments.append((nsText.substring(from: lastPos), false))
        }
        
        return segments
    }
    
    // Encode the input text into tokens and corresponding token IDs
    func encode(_ text: String) -> ([Data], [Int]) {
        var tokenIDs: [Int] = []
        var tokens: [Data] = []
        
        // Step 1: Split text by special tokens
        let segments = splitBySpecialTokens(text)
        
        for (segment, isSpecial) in segments {
            if isSpecial {
                // If it is a special token, append its ID
                let tokenData = segment.data(using: .utf8)!
                tokens.append(tokenData)
                tokenIDs.append(specialTokens[segment]!)
            } else {
                // Apply BPE to non-empty segments
                if !segment.trimmingCharacters(in: .whitespaces).isEmpty {
                    let bpeTokens = bytePairEncode(segment.utf8.map { UInt8($0) })
                    tokens.append(contentsOf: bpeTokens)
                    for bpeToken in bpeTokens {
                        let bpeTokenData = bpeToken
                        tokenIDs.append(ranks[bpeTokenData] ?? 0)  // Default to 0 if not found
                    }
                }
            }
        }
        
        return (tokens, tokenIDs)
    }
    
    // Apply BPE algorithm to a list of bytes and return the tokens
    func bytePairEncode(_ piece: [UInt8]) -> [Data] {
        var tokens = piece.map { Data([ $0 ]) }  // Convert bytes to Data objects
        
        while tokens.count > 1 {
            var minRank = Int.max
            var minPair: (Int, Int)?
            
            // Find the best pair of adjacent tokens to merge
            for i in 0..<tokens.count - 1 {
                let pair = tokens[i] + tokens[i + 1]  // Merge adjacent Data objects
                if let rank = ranks[pair], rank < minRank {
                    minRank = rank
                    minPair = (i, i + 1)
                }
            }
            
            // Break loop if no pair found
            if minPair == nil {
                break
            }
            
            // Merge the best pair found
            tokens[minPair!.0] += tokens[minPair!.1]  // Merge two Data objects
            tokens.remove(at: minPair!.1)  // Remove the second token
        }
        
        // Convert Data objects back to String for output (if needed)
        return tokens
    }
    //    func decode(_ tokenIDs: [Int]) -> String {
    //        var text = ""
    //        for tokenID in tokenIDs {
    //            // Check if the token ID is present in the reverse vocab
    //            if let tokenData = reverseVocab[tokenID] {
    //                if let token = String(data: tokenData, encoding: .utf8) {
    ////                    print(token)
    //
    //                    if specialTokens.values.contains(tokenID) {
    //                        text += token
    //                    } else {
    //                        // Join regular tokens with a space
    //                        text += token
    //                    }
    //                } else {
    //                    // 수동으로 디코딩 후 잘못된 문자 무시
    //                    let token = String(data: tokenData, encoding: .ascii) ?? ""
    ////                    print(token)
    //
    //                    if specialTokens.values.contains(tokenID) {
    //                        text += token
    //                    } else {
    //                        // Join regular tokens with a space
    //                        text += token
    //                    }
    //                }
    //
    //            }
    //        }
    //
    //        return text
    //    }
    func decode(_ tokenIDs: [Int]) -> String {
        var decodedText = Data()
        
        for tokenID in tokenIDs {
            // Check if the token ID is present in the reverse vocab
            if let tokenData = reverseVocab[tokenID] {
                decodedText.append(tokenData)
            }
        }
        // 데이터를 UTF-8 문자열로 변환
//        if let utf8String = String(data: data, encoding: .utf8) {
//            print(utf8String)
//        } else {
//            // 변환에 실패한 경우 처리
//            let validString = String(data: data, encoding: .utf8, options: .init(rawValue: 0))
//            print(validString)
//        }
        return String(data: decodedText, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
