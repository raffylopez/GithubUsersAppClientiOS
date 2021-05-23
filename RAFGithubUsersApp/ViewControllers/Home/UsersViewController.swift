//
//  ViewController.swift
//  RAFGithubUsersApp
//
//  Created by Volare on 5/11/21.
//  Copyright © 2021 Raf. All rights reserved.
//

import UIKit

class UsersViewController: UITableViewController {
    let scene = UIApplication.shared.connectedScenes.first!.delegate as! SceneDelegate

    init(viewModel: UsersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) not supported by \(String(describing:Self.self))")
    }

    fileprivate func startSplashAnimation() {
        let icon: SKSplashIcon = SKSplashIcon(image: UIImage(named: "github_splash_dark")!)
        guard let splashView = SKSplashView(splashIcon: icon, animationType: .none),
            let navController = self.navigationController
        else { return }
        splashView.backgroundColor = .black
        splashView.animationDuration = 2.0
        navController.view.addSubview(splashView)
        splashView.startAnimation()
    }
    
    // MARK: - Configurables
    /**
     Enables look-ahead prefetching for table cells for infinite-scroll implementation.
     If false, tail-end fetching is used.
     */
    let confPrefetchingEnabled: Bool = false
    
    /**
     Cached images need to be reloaded after toggling this flag
     */
    let confImageInversionOnFourthRows: Bool = true
    
    private func setupReachability() {
        ConnectionMonitor.shared.delegate = self
        ConnectionMonitor.shared.checkNetworkSignal(start: .now())
    }
    
    // MARK: Configure table cell types
//    typealias StandardTableViewCell = NormalUserTableViewCell
//    typealias StandardNotedTableViewCell = NoteNormalUserTableViewCell
//    typealias AlternativeTableViewCell = InvertedUserTableViewCell
//    typealias AlternativeNotedTableViewCell = NoteInvertedUserTableViewCell
    typealias StandardTableViewCell = DebugUserTableViewCell
    typealias StandardNotedTableViewCell = DebugNotedUserTableViewCell
    typealias AlternativeTableViewCell = DebugUserTableViewCell
    typealias AlternativeNotedTableViewCell = DebugNotedUserTableViewCell

    // MARK: - Properties and attributes
    var viewModel: UsersViewModel!
    lazy var search: UISearchController = {
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search (\"quote\" for exact match)"
        search.searchBar.autocapitalizationType = .none
        search.searchBar.autocorrectionType = .no
        search.searchBar.sizeToFit()
        search.searchBar.smartQuotesType = .no
        search.searchBar.smartDashesType = .no
        search.searchBar.smartInsertDeleteType = .no
        return search
    }()
    
    lazy var tap: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        return tap
    }()

    lazy var tapButton: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tableViewScrollToTop))
        tap.cancelsTouchesInView = false
        return tap
    }()

    // MARK: - Table cell registration
    /**
     Registers table cell types with reuse identifiers, used for dequeueing cells
     */
    private func registerReuseId<T>(_ type: T.Type) where T: UserTableViewCellBase {
        self.tableView?.register(T.self, forCellReuseIdentifier: String(describing: T.self))
    }

    private func registerTableCellTypes() {
        registerReuseId(StandardTableViewCell.self)
        registerReuseId(StandardNotedTableViewCell.self)
        registerReuseId(AlternativeTableViewCell.self)
        registerReuseId(AlternativeNotedTableViewCell.self)
    }
    
    /**
     Generic method that uses reflection to obtain a table view cell subtype instance,
     with dequeue identifier based on reflected type
     */
    private func cellInstance<T>(user: User, _ type: T.Type, cellForRowAt indexPath: IndexPath) -> T where T:UserTableViewCellBase {
        let cell  = tableView.dequeueReusableCell(withIdentifier: String(describing: T.self), for: indexPath)
        if let cell = cell as? T {
            cell.user = user
            cell.indexPath = indexPath
            cell.delegate = self
            cell.owningController = self
            return cell
        }
        fatalError("Cannot dequeue to \(String(describing:T.self))")
    }

    // MARK: - Setup
    private func setupTableView() {
        self.tableView.addGestureRecognizer(tap)
        self.tableView.scrollsToTop = true
        self.tableView.prefetchDataSource = self
        registerTableCellTypes()
    }

    /**
     Displays a toast message at the bottom.
     
     Navigation controller should be the receiver, otherwise toast
     might be misplaced or obscured.
     
     Display is always performed in the main queue
     */
    private func makeToast(message:String, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.navigationController?.view.makeToast(message, duration: duration, position: .bottom)
        }
    }
    
    private func multiple(of number: Int, _ value: Int, includingFirst: Bool = false) -> Bool {
        if includingFirst {
            return value % number == 0
        }
        return value % number == 0 && value != 0
    }
    
    private func performInvertedImagesPrefetching() {
        guard confImageInversionOnFourthRows else {
            return
        }
        
        var i: Int = 0
        for user in self.targetSource {
            guard self.viewModel.imageStore.image(forKey: "\(user.id)") == nil else  { continue }
            if multiple(of: 4, i + 1) {
                self.viewModel.fetchImage(for: user, queued: true) { result in
                    if case let .success(img) = result, let inverted = img.0.invertImageColors() {
                        self.viewModel.imageStore.setImage(forKey: "\(user.id)", image: inverted)
                    }
                }
            }
            
            i += 1
        }
    }
    

    
    private func setupViewModel() {
        self.viewModel.delegate = self
        
        /* Callback handler for when data is available in current datasource */
        let onDataAvailable = {
//            guard self.viewModel.lastDataSource != .parkedFromSearch else {
//                self.tableView.reloadData()
//                return
//            }
            guard !self.targetSource.isEmpty, !self.search.isActive else {
                self.tableView.reloadData()
                return
            }

            /* Partial tableView refreshing */
            OperationQueue.main.addOperation {
                ToastAlertMessageDisplay.main.hideToastActivity()
                
                if self.viewModel.totalDisplayCount <= 30 { /* User performed a refresh/first load */
                    self.tableView.alpha = 0
                    self.tableView.alpha = 1
                    UIView.transition(with: self.tableView,
                                      duration: 0.0,
                                      options: [],
                                      animations: {
                                        self.tableView.alpha = 1
                                        self.tableView?.reloadSections(IndexSet(integer: 0), with: .none)
                    }, completion: { _ in
                        /* Fix graphical glitch when pull-to-refresh is started when navbar is collapsed */
//                        self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    })
                    self.refreshControl?.endRefreshing()
                    return
                }

                let startIndex = self.viewModel.totalDisplayCount - 30
                let endIndex = startIndex + 30
                let newIndexPathsToInsert: [IndexPath] = (startIndex..<endIndex).map { IndexPath(row: $0, section: 0) }
                let indexPathsToReload = self.visibleIndexPathsToReload(intersecting: newIndexPathsToInsert)

                /**/
                if self.viewModel.lastDataSource != .parkedFromSearch {
                    /* Ensure slide animations are disabled on row insertion (slide animation used by default on insert) */
                    UIView.setAnimationsEnabled(false)
                    self.tableView?.beginUpdates()
                    self.tableView?.insertRows(at: newIndexPathsToInsert, with: .none)
                    self.tableView?.endUpdates()
                }
                
                self.viewModel.lastDataSource = .unspecified
                UIView.setAnimationsEnabled(true)
                
                self.tableView?.reloadRows(at: indexPathsToReload, with: .fade)
            }
        }
        self.viewModel.bind(availability: onDataAvailable)
    }

    let titleLabel = UILabel()
    private func setupNavbar() {
        let imgSize = CGFloat(24)
//        let imgHeight = CGFloat(imgSize)
//        let imgWidth = CGFloat(imgSize)
        let spacing = CGFloat(5.0)
//        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
//        imageView.contentMode = .scaleAspectFit
//        let img = UIImage(named: "github_splash_light")!
//        imageView.image = img
        let container = UIView()
        let label = UILabel()
        label.text = "".localized()
        label.sizeToFit()
        UIHelper.initializeView(view: label, parent: container)
        label.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: (imgSize + spacing) / 2).isActive = true
        label.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
        
//        UIHelper.initializeView(view: imageView, parent: container)
//        imageView.rightAnchor.constraint(equalTo: label.leftAnchor, constant: spacing * -1).isActive = true
//        imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
//        imageView.widthAnchor.constraint(equalToConstant: imgSize).isActive = true
//        imageView.heightAnchor.constraint(equalToConstant: imgSize).isActive = true
        
//        self.navigationItem.titleView = container
        titleLabel.font = UIFont.fontAwesome(ofSize: 20, style: .brands)
        titleLabel.text = String.fontAwesomeIcon(name: .github)
        
        let tapNavIcon = UITapGestureRecognizer(target: self, action: #selector(tableViewScrollToTop))
        tapNavIcon.cancelsTouchesInView = false
        self.navigationItem.titleView = titleLabel
        self.navigationItem.titleView?.isUserInteractionEnabled = true
        self.navigationItem.titleView?.addGestureRecognizer(tapNavIcon)
        //        let bbi: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(tableViewScrollToTop))
        //        let leftBarItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(tableViewScrollToTop))
        //        let rightBarItem: UIBarButtonItem = UIBarButtonItem(image: img.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: nil)
        //        navigationItem.leftBarButtonItem = leftBarItem
        self.navigationItem.searchController = search
        self.title = "Browse Users".localized()
        let leftBarItem = UIBarButtonItem(title: "Refresh Stale".localized(), style: .plain, target: self, action: #selector(self.refreshStaleOnDemand))
        self.navigationItem.leftBarButtonItem = leftBarItem
    }
    
    func refreshStaleOnScroll(imageFetchCompletion: (((UIImage, ImageSource))->Void)? = nil, completion: @escaping ()->Void) {
        self.viewModel.refreshStale { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    let startIndex = self.viewModel.totalDisplayCount - 30
                    let endIndex = startIndex + 30
                    let newIndexPathsToInsert: [IndexPath] = (startIndex..<endIndex).map { IndexPath(row: $0, section: 0) }
                    let indexPathsToReload = self.visibleIndexPathsToReload(intersecting: newIndexPathsToInsert)
                    self.tableView?.beginUpdates()
                    self.tableView?.reloadRows(at: indexPathsToReload, with: .fade)
                    self.tableView?.endUpdates()
                }
                completion()
            case .failure:
                completion()
            }

        }
    }

    @objc func refreshStaleOnDemand() {
        scene.appConnectionState = scene.appConnectionState == .networkUnreachable ?
            .networkReachable : .networkUnreachable
        self.viewModel.refreshStale { result in
            DispatchQueue.main.async {
                let contentOffset = self.tableView.contentOffset
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
                self.tableView.setContentOffset(contentOffset, animated: false)
            }
        }
    }
    private func setupViews() {
        setupNavbar()
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)

    }

    // MARK: - ViewController methods
    override func loadView() {
        super.loadView()
        setupViews()
        setupTableView()
        self.view.backgroundColor = UIColor.systemBackground

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        ToastAlertMessageDisplay.main.hideAllToasts()
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationItem.largeTitleDisplayMode = .always
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startSplashAnimation()
        self.view.backgroundColor = .systemBackground
        setupViewModel()
        setupReachability()
        self.fetchMoreTableDataDisplayingResults()
    }
    
    private func clearData() {
        self.viewModel.clearData()
        self.viewModel.imageStore.removeAllImages()
        self.tableView.reloadData() // TODO
    }
    
    // MARK: - Selector targets
    @objc private func refreshPulled() {
        self.refreshControl?.beginRefreshing()
        clearData()
        fetchMoreTableDataDisplayingResults()
    }
    
    func fetchMoreTableDataDisplayingResults(completion: (()->Void)? = nil) {
        ToastAlertMessageDisplay.main.makeToastActivity()
        self.viewModel.updateUsers {
            ToastAlertMessageDisplay.main.hideToastActivity()
        }
//        self.viewModel.fetchUsers { result in
//            DispatchQueue.main.async {
//                self.refreshControl?.endRefreshing()
//                if case let .failure(error) = result {
//                    print(error) // TODO
//                }
//            }
//        }
    }

    @objc func tableViewScrollToTop() {
        let animated = self.tableView.contentOffset.y <= (self.tableView.frame.height * 5)
        self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: animated)
    }
    
    /**
     Selectable method for tap gesture recognizer, for dismissing search
     when user clicks out of keyboard/searchbox. Needs gesture recognizer
     to have cancelsTouchesInView set to false
     */
    @objc func dismissKeyboard() {
        if self.search.isActive { return }
        search.dismiss(animated: true, completion: nil)
    }

    var isRefreshing = false

    var targetSource:[User] { return search.isActive ? self.viewModel.filteredUsers : self.viewModel.users }
    
    // MARK: - UITableViewDelegate methods
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !self.targetSource.isEmpty && self.targetSource.count - 1 >= indexPath.row else {
            return
        }
        let element = targetSource[indexPath.row]
        
        if !search.isActive {
            if isLoadingLastCell(for: indexPath) {
                fetchMoreTableDataDisplayingResults()
            }
            if let cell = cell as? UserTableViewCellBase, !isRefreshing, self.viewModel.staleIds.contains(cell.user.id) {
                isRefreshing = true
                self.refreshStaleOnScroll(completion: {
                    self.isRefreshing = false
                })
            }
        }
        self.viewModel.fetchImage(for: element, queued: true) { result in
            guard let photoIndex = self.targetSource.firstIndex(of: element),
                case let .success(image) = result else {
                    return
            }
            if let cell = self.tableView.cellForRow(at: IndexPath(item: photoIndex, section: 0)) as? StandardTableViewCell {
                DispatchQueue.main.async {
                    cell.update(displaying: image)
                }
                return
            }
            if let cell = self.tableView.cellForRow(at: IndexPath(item: photoIndex, section: 0)) as? AlternativeTableViewCell {
                DispatchQueue.main.async {
                    cell.update(displaying: image)
                }
                return
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.targetSource.count > 0 {
        return self.targetSource.count
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // TODO: Dynamic height computation
        return 100
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    private func calculateIndexPathsToInsert(from newUsers: Int, offset: Int = 0) -> [IndexPath] {
        let startIndex = (self.targetSource.count - newUsers) + offset
        let endIndex = (startIndex + newUsers)
        print("STATS vmuc:\(self.targetSource.count), n:\(newUsers)")
        print("STATS STARTINDEX: \(startIndex), ENDINDEX: \(endIndex)")
//        if self.viewModel.currentPage == 1 {
//            return ((startIndex)..<(endIndex-1)).map { IndexPath(row: $0, section: 0) }
//        }
//        return ((startIndex < 0 ? startIndex : startIndex - 1)..<(endIndex-1)).map { IndexPath(row: $0, section: 0) }
//        return (startIndex-1..<endIndex-1).map { IndexPath(row: $0, section: 0) }
        return (startIndex..<endIndex).map { IndexPath(row: $0, section: 0) }
    }

    func isLoadingLastCell(for indexPath: IndexPath) -> Bool {
        return indexPath.row + 1 >= self.targetSource.count
    }
}

// MARK: - Delegate Methods
// MARK: • UITableViewDatasource methods
extension UsersViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !self.targetSource.isEmpty && self.targetSource.count - 1 >= indexPath.row else {
//            self.tableView.reloadData()
            return UITableViewCell()
        }
        
        let user = self.targetSource[indexPath.row]
        var cell: UserCell!

        let hasNote = user.userInfo != nil && user.userInfo?.note != nil && user.userInfo?.note != ""
        
        if (multiple(of: 4, indexPath.row + 1) && confImageInversionOnFourthRows) {
            cell = hasNote ?
                cellInstance(user: user, AlternativeNotedTableViewCell.self, cellForRowAt: indexPath) :
                cellInstance(user: user, AlternativeTableViewCell.self, cellForRowAt: indexPath)
            cell.tag = indexPath.row
            cell.updateCell()
            return cell
        }
        cell = hasNote ?
            cellInstance(user: user, StandardNotedTableViewCell.self, cellForRowAt: indexPath) :
            cellInstance(user: user, StandardTableViewCell.self, cellForRowAt: indexPath)
        cell.tag = indexPath.row
        cell.updateCell()

        return cell
    }
}

// MARK: • Cell Touch Delegate Methods
extension UsersViewController: UserListTableViewCellDelegate {
    func didTouchImageThumbnail(view: UIImageView, cell: UserTableViewCellBase, element: User) {
    }
    
    func didTouchCellPanel(cell: UserTableViewCellBase) {
        guard !self.viewModel.isFetchInProgress else {
            return
        }
        let viewModel = ProfileViewModel(cell: cell, apiService: GithubUsersApi(), databaseService: CoreDataService.shared)
        let profileViewController = ViewControllersFactory.instance(vcType: .userProfile(viewModel)) as! ProfileViewController
        profileViewController.delegate = self
        self.navigationController?.pushViewController(profileViewController, animated: true)
    }
    
}

extension UsersViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        // TODO
//        self.viewModel.clearUsers()
        self.viewModel.lastDataSource = .parkedFromSearch
        guard let text = searchController.searchBar.text else {
            return
        }
        self.viewModel.searchUsers(for: text)
        self.tableView.reloadData()
    }
    
}

extension UsersViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
//        if confPrefetchingEnabled && indexPaths.contains(where: isLoadingCell) {
//            fetchAdditionalTableData()
//        }
    }
}

extension UsersViewController {
    func isLoadingCell(for indexPath: IndexPath) -> Bool {
        return (indexPath.row + 1) >= self.viewModel.currentCount
    }
    
    func visibleIndexPathsToReload(intersecting indexPaths: [IndexPath]) -> [IndexPath] {
        let indexPathsForVisibleRows = tableView.indexPathsForVisibleRows ?? []
        let indexPathsIntersection = Set(indexPathsForVisibleRows).intersection(indexPaths)
        return Array(indexPathsIntersection)
    }
}

extension UsersViewController: ReachabilityDelegate {
    func onLostConnection() {
        scene.appConnectionState = .networkUnreachable
    }
    
    func onRegainConnection() {
        scene.appConnectionState = .networkReachable
    }
}

extension UsersViewController: ViewModelDelegate {

    func onRetryError(n: Int, nextAttemptInMilliseconds: Int, error: Error) {
            self.makeToast(message: "Unable to load data (\(n)). Retrying in \(nextAttemptInMilliseconds/1000) secs", duration: 3.0)
        DispatchQueue.main.async {
            self.navigationItem.rightBarButtonItem = nil
        }
    }
    
    func onDataAvailable() {
        DispatchQueue.main.async {
            let rightBarItem = UIBarButtonItem(title: "Scroll to Top".localized(), style: .plain, target: self, action: #selector(self.tableViewScrollToTop))
            self.navigationItem.rightBarButtonItem = rightBarItem
        }
    }
    
    func onFetchInProgress() {
        //
    }
    
    func onFetchDone() {
        //
    }
}

extension UsersViewController: ProfileViewDelegate {
    func didSaveNote(at indexPath: IndexPath) {
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    func didSeeProfile(at indexPath: IndexPath) {
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
}
