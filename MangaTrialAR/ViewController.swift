//
//  ViewController.swift
//  MangaTrialAR
//
//  Created by Rina Kotake on 2019/12/21.
//  Copyright © 2019 Rina Kotake. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!

    var session: ARSession {
        return sceneView.session
    }

    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".serialSceneKitQueue")

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        resetTracking()
    }

    let nekonotes: [UIImage] = [
        #imageLiteral(resourceName: "nekonote1"),
        #imageLiteral(resourceName: "nekonote2"),
        #imageLiteral(resourceName: "nekonote3"),
        #imageLiteral(resourceName: "nekonote4")
    ]
    var nekonoteIndex = 0

    let hanakakus: [UIImage] = [
        #imageLiteral(resourceName: "hanakaku1"),
        #imageLiteral(resourceName: "hanakaku2"),
        #imageLiteral(resourceName: "hanakaku3"),
        #imageLiteral(resourceName: "hanakaku4")
    ]
    var hanakakuIndex = 0

    func resetTracking() {
        // Assetsの読み込み
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }

        // 既知の2D画像を追跡するconfigの設定
        let configuration = ARImageTrackingConfiguration()
        configuration.trackingImages = referenceImages
        // ARオブジェクトの手前に人が映り込む時、オクルージョン処理してくれる設定
       // configuration.frameSemantics = .personSegmentation

        // session開始
        // .resetTracking: デバイスの位置をリセットする
        // .removeExistingAnchors: 配置したオブジェクトを取り除く
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // session停止
        sceneView.session.pause()
    }

    var imageAction: SCNAction {
        return .sequence([
            .scale(to: 1.5, duration: 0.3),//スケール
            .scale(to: 1, duration: 0.2),
            .fadeOpacity(to: 0.8, duration: 0.5),//フェード
            .fadeOpacity(to: 0.1, duration: 0.5),
            .fadeOpacity(to: 0.8, duration: 0.5),
            .move(to: SCNVector3(0.0, 0.0, 0.0), duration: 1),//移動
            .fadeOpacity(to: 1.0, duration: 0.5),
        ])
    }



    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard
            let location = touches.first?.location(in: sceneView),
            let result = sceneView.hitTest(location, options: nil).first else {
                return
        }
        // ノードの名前を取得し画像変更
        let node = result.node
        let objectImage: UIImage
        switch node.name {
        case "nekonote" :
            nekonoteIndex += 1
            objectImage = nekonotes[nekonoteIndex % 4]
        case "hanakaku":
            hanakakuIndex += 1
            objectImage = hanakakus[hanakakuIndex % 4]
        default:
            return
        }
        // アニメーションしながら画像差し替え
        node.runAction(self.pageStartAction, completionHandler: {
            node.geometry?.firstMaterial?.diffuse.contents = objectImage
            node.runAction(self.pageEndAction, completionHandler: nil)
        })
    }

    var pageStartAction: SCNAction {
        return .fadeOpacity(to: 0.0, duration: 0.1)
    }
    var pageEndAction: SCNAction {
        return .fadeOpacity(to: 1.0, duration: 0.2)
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    // 新しいARアンカーに対応するノードが追加されたことを通知
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else {
            return
        }
        // 表示したいオブジェクトをARアンカーの名前から決定
        let objectImage: UIImage
        switch imageAnchor.referenceImage.name {
        case "nekonote" :
            objectImage = nekonotes[nekonoteIndex]
        case "hanakaku":
            objectImage = hanakakus[hanakakuIndex]
        default:
            return
        }

        updateQueue.async {
            // sceneにノードを追加
            node.addChildNode(self.createNode(image: objectImage, name: imageAnchor.referenceImage.name ?? "no name"))
        }
    }

    private func createNode(image: UIImage, name: String) -> SCNNode {
        // 検出されたARアンカーの位置を視覚化する平面に合わせて、長方形のノード（SCNPlane）を作成
        let scale: CGFloat = 0.2
        let plane = SCNPlane(width: image.size.width * scale / image.size.height,
                             height: scale)
        // firstMaterial:平面の最初のマテリアル
        // diffuse: 表面から拡散反射される光の量、拡散光はすべての方向に等しく反射されるため、視点に依存しない、contentsに画像をset
        plane.firstMaterial?.diffuse.contents = image
        plane.firstMaterial?.colorBufferWriteMask = .all
        let planeNode = SCNNode(geometry: plane)
        planeNode.name = name
        // SCNPlaneはローカル座標空間で垂直方向を向いているが、ARアンカーは画像が水平であると想定しているため
        // 一致するように回転させる
        planeNode.eulerAngles.x = -.pi / 2
        // アニメーション
        planeNode.position = SCNVector3(0.0, 0.0, -0.15)
        planeNode.scale = SCNVector3(0.1, 0.1, 0.1)
        planeNode.runAction(self.imageAction)
        return planeNode
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        print("SESSION ERROR")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("SESSION INTERRUPTED")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.resetTracking() //セッション再開
        }
    }
}
