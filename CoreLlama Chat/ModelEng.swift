//
//  ModelEng.swift
//  Don-Quixote
//
//  Created by 하늘 on 10/19/24.
//

import Foundation
import CryptoKit
import CoreML

class ModelLoader {
    static func load(url: URL?) async throws -> MLModel {
        guard let url = url, url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "ModelLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL or unable to access resource"])
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // 컴파일된 모델 경로를 얻기
        let compiledModelURL = try await MLModel.compileModel(at: url)
        
        // 모델 로드
        let modelConfig = MLModelConfiguration()
        modelConfig.computeUnits = .cpuAndGPU
        return try MLModel(contentsOf: compiledModelURL, configuration: modelConfig)
    }
}

public class LLM {
    public let model: MLModel
    public var state: MLState?
    public var pos: Int = 0
    
    let input_ids = "input_ids"
    let causal_mask = "causal_mask"
    
    public var stopTokens: [Int] = [128001, 128009]
    
    public init(model: MLModel) {
        self.model = model
    }
    
    public func make_causal_mask(seqlen: Int, pos:Int) async ->  MLShapedArray<Float32> {
        let largeNegativeValue: Float = -1e9
        
        let mask = MLTensor(repeating: largeNegativeValue, shape: [seqlen, seqlen])

        // Step 2: Apply upper triangular mask (keeping diagonal=1)
        let maskUpperTri = mask.bandPart(lowerBandCount: 0, upperBandCount: -1)

        // Step 3: Concatenate zero tensor of shape (seqLen, 0) with the mask
        let zeroTensor = MLTensor(zeros: [seqlen, pos], scalarType: Float.self)
        let concatenatedMask = zeroTensor.concatenated(with: maskUpperTri, alongAxis: 1)

        // Step 4: Add additional dimensions (equivalent to None in PyTorch)
        let finalMask = concatenatedMask.expandingShape(at: 0, 1)
        
        let causlaMask:MLShapedArray<Float32> = await finalMask.shapedArray(of: Float32.self)

        return causlaMask
    }
    
    public func inference(tokens_array: MLShapedArray<Int32>, causlaMask:MLShapedArray<Float32>, state: MLState) async throws -> MLShapedArray<Float16> {
        let inputDictionary = [input_ids: MLFeatureValue(shapedArray: tokens_array), causal_mask: MLFeatureValue(shapedArray: causlaMask)]
        let input = try! MLDictionaryFeatureProvider(dictionary: inputDictionary)
        let output = try await model.prediction(from: input, using: state)
        assert(output.featureNames.first! == "logits")
        guard let firstFeatureName = output.featureNames.first else {
            return [0 as Float16]
        }
        
        
        let featureValue = output.featureValue(for: firstFeatureName)
        guard let scores = featureValue?.shapedArrayValue(of: Float16.self) else { return [0 as Float16] }
        
        return scores
    }
    public func openLoop(tokens : [Int], open_func: @escaping ([Int]) -> Bool) async ->  [Int]{
        print("tokens \(tokens)")
        var seqlen = tokens.count
        var totalLen = 1
        guard seqlen > 0 else { return [401] }
        var decode_tokens: [Int32] = []
        
        /// Request a state
        let state:MLState = model.makeState()
        var tokens_array = MLShapedArray<Int32>(scalars: tokens.map(Int32.init), shape: [1, seqlen])
        
        
        do {
            for _ in 0..<1024{
                
                let causlaMask: MLShapedArray<Float32> = await make_causal_mask(seqlen: seqlen, pos: totalLen)
                print("causlaMask Shape : \(causlaMask.shape)")
                let scores = try await inference(tokens_array: tokens_array, causlaMask: causlaMask, state: state)

                let tokenScore = MLTensor(scores)[0, ...].argmax(alongAxis: -1)
                let reshapeArray = await tokenScore.shapedArray(of: Int32.self).reshaped(to: [1])

                decode_tokens.append(reshapeArray.scalars.first!)
                for stopT in stopTokens {
                    if reshapeArray.scalars.first! == stopT {
                        return decode_tokens.map(Int.init)
                    }
                }
                tokens_array = reshapeArray.reshaped(to: [1, 1])
                totalLen += seqlen
                seqlen = 1
                if !open_func(decode_tokens.map(Int.init)) {
                    return decode_tokens.map(Int.init) + [stopTokens.first!]
                }
            }
            return decode_tokens.map(Int.init)
            

        } catch {
            
        }
        return [404]
    }

    
    public func closeLoop(tokens : [Int]) async ->  [Int]{
        print("tokens \(tokens)")
        var seqlen = tokens.count
        var totalLen = 1
        guard seqlen > 0 else { return [401] }
        var decode_tokens: [Int32] = []
        
        /// Request a state
        let state:MLState = model.makeState()
        var tokens_array = MLShapedArray<Int32>(scalars: tokens.map(Int32.init), shape: [1, seqlen])
        
        
        do {
            for _ in 0..<1024{
                
                let causlaMask: MLShapedArray<Float32> = await make_causal_mask(seqlen: seqlen, pos: totalLen)
                print("causlaMask Shape : \(causlaMask.shape)")
                let scores = try await inference(tokens_array: tokens_array, causlaMask: causlaMask, state: state)

                let tokenScore = MLTensor(scores)[0, ...].argmax(alongAxis: -1)
                let reshapeArray = await tokenScore.shapedArray(of: Int32.self).reshaped(to: [1])

                decode_tokens.append(reshapeArray.scalars.first!)
                for stopT in stopTokens {
                    if reshapeArray.scalars.first! == stopT {
                        return decode_tokens.map(Int.init)
                    }
                }
                tokens_array = reshapeArray.reshaped(to: [1, 1])
                totalLen += seqlen
                seqlen = 1
            }
            return decode_tokens.map(Int.init)
            

        } catch {
            
        }
        return [404]
    }
    
    
    var inputIdsDescription: MLFeatureDescription {
        model.modelDescription.inputDescriptionsByName[input_ids]!
    }

    var inputIdsName: String {
        inputIdsDescription.name
    }
    
    
    
    var causal_maskDescription: MLFeatureDescription {
        model.modelDescription.inputDescriptionsByName[causal_mask]!
    }

    var inputPosName: String {
        inputIdsDescription.name
    }
}
