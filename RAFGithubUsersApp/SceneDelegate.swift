//
//  SceneDelegate.swift
//  RAFGithubUsersApp
//
//  Created by Volare on 5/11/21.
//  Copyright © 2021 Raf. All rights reserved.
//

import UIKit


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var navigationController: GithubUsersAppNavController!

    var appConnectionState: AppConnectionState = ConnectionMonitor.shared.isApiReachable ? .networkReachable : .networkUnreachable {
        didSet {
            switch appConnectionState {
            case .networkReachable:
                navigationController.onNetworkReachable()
            case .networkUnreachable:
                navigationController.onNetworkUnreachable()
            }
        }
    }
    var window: UIWindow?

    
    private func setupViewControllers() {
        // constructor dependency injection
        let viewModel = UsersViewModel(apiService: GithubUsersApi(), databaseService: CoreDataService.shared)
        let top = ViewControllersFactory.instance(vcType: .usersList(viewModel))
        navigationController = GithubUsersAppNavController(rootViewController: top)
        navigationController.navigationBar.barStyle = .default
        
//        let icon: SKSplashIcon = SKSplashIcon(image: UIImage(named: "github_splash_dark")!)
//        guard let splashView = SKSplashView(splashIcon: icon, animationType: .none)
//            else { return }
//        splashView.backgroundColor = .black
//        splashView.animationDuration = 2.5
//        navController.view.addSubview(splashView)
//        splashView.startAnimation()

        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
    

    func dbgClearDataStoresOnAppLaunch() {
        let context = CoreDataService.persistentContainer.viewContext
        let usersDatabaseService = CoreDataService.shared
        context.performAndWait {
            try? usersDatabaseService.deleteAll()
        }
        do {
            try context.save()
        } catch {
            fatalError("Can't delete coredata store")
        }
        //        try? userInfoProvider.delete()
        //        updateUsers() {
        //            self.loadUsersFromDisk()
        //        }
    }
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = (scene as? UIWindowScene) else { return }
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.windowScene = scene
//        dbgClearDataStoresOnAppLaunch() // DEBUG
        setupViewControllers()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }

}
