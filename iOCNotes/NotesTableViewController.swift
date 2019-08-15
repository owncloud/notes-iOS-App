//
//  NotesTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import CoreData
import PKHUD
import SwiftMessages
import UIKit

let detailSegueIdentifier = "showDetail"
let categorySegueIdentifier = "SelectCategorySegue"

protocol NoteCategoryDelegate: class {
    func selectCategory(_ indexPath: IndexPath) 
}

class NotesTableViewController: UITableViewController {

    @IBOutlet var addBarButton: UIBarButtonItem!
    @IBOutlet var settingsBarButton: UIBarButtonItem!

    var notes: [CDNote]?
    var addingNote = false
    var searchController: UISearchController?
    var editorViewController: EditorViewController?
    
    private var networkHasBeenUnreachable = false
    private var searchResult: [CDNote]?
    private var indexPathForCategory: IndexPath?
    private var numberOfObjectsInCurrentSection = 0

    private lazy var notesFrc: NSFetchedResultsController<CDNote> = configureFRC()
    private var observers = [NSObjectProtocol]()
    private var sectionExpandedInfo = [Bool]()
    private var sectionExpandedInfoCount = 1
    
    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        clearsSelectionOnViewWillAppear = false
        refreshControl?.tintColor = UIColor(red: 0.13, green: 0.145, blue: 0.16, alpha: 1.0)

        self.observers.append(NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        self?.tableView.reloadData()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        if KeychainHelper.server.isEmpty {
                                                                            self?.onSettings(sender: self)
                                                                        } else {
                                                                            if KeychainHelper.syncOnStart,
                                                                                NotesManager.isOnline {
                                                                                NotesManager.shared.sync()
                                                                            }
                                                                        }
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .deletingNote,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
                                                                        if let editor = self?.editorViewController,
                                                                            let note = editor.note,
                                                                            let currentIndexPath = self?.notesFrc.indexPath(forObject: note), let tableView = self?.tableView {
                                                                                self?.tableView(tableView, commit: .delete, forRowAt: currentIndexPath)
                                                                                }
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .syncNotes,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
                                                                        self?.onRefresh(sender: nil)
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .networkSuccess,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
                                                                        HUD.hide()
                                                                        self?.refreshControl?.endRefreshing()
                                                                        self?.addBarButton.isEnabled = true
                                                                        self?.settingsBarButton.isEnabled = true
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .networkError,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        HUD.hide()
                                                                        self?.refreshControl?.endRefreshing()
                                                                        self?.addBarButton.isEnabled = true
                                                                        self?.settingsBarButton.isEnabled = true
                                                                        if let title = notification.userInfo?["Title"] as? String,
                                                                            let message = notification.userInfo?["Message"] as? String {
                                                                            var config = SwiftMessages.defaultConfig
                                                                            config.interactiveHide = true
                                                                            config.duration = .forever
                                                                            config.preferredStatusBarStyle = .default
                                                                            SwiftMessages.show(config: config, viewProvider: {
                                                                                let view = MessageView.viewFromNib(layout: .cardView)
                                                                                view.configureTheme(.error, iconStyle: .default)
                                                                                view.configureDropShadow()
                                                                                view.configureContent(title: title,
                                                                                                      body: message,
                                                                                                      iconImage: Icon.error.image,
                                                                                                      iconText: nil,
                                                                                                      buttonImage: nil,
                                                                                                      buttonTitle: nil,
                                                                                                      buttonTapHandler: nil
                                                                                )
                                                                                return view
                                                                            })
                                                                        }
        })
        )
/*
         [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(reachabilityChanged:)
         name:AFNetworkingReachabilityDidChangeNotification
         object:nil];

*/
        let nib = UINib(nibName: "CollapsibleTableViewHeaderView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "HeaderView")
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        splitViewController?.delegate = self;
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.hidesNavigationBarDuringPresentation = true
        searchController?.dimsBackgroundDuringPresentation = false
        searchController?.searchBar.delegate = self
        searchController?.searchBar.sizeToFit()
        searchController?.searchBar.tintColor = UIColor(red:0.12, green:0.18, blue:0.26, alpha:1.0)
        searchController?.searchBar.barTintColor = UIColor(red:0.957, green:0.957, blue:0.957, alpha:0.95)
        searchController?.searchBar.backgroundImage = UIImage()
        tableView.tableHeaderView = searchController?.searchBar
        tableView.contentOffset = CGPoint(x: 0, y: searchController?.searchBar.frame.size.height ?? 0.0 + tableView.contentOffset.y)
        tableView.dropDelegate = self
        tableView.reloadData()
        definesPresentationContext = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didBecomeActive()
    }
        
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let sections = notesFrc.sections {
            return sections.count
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sectionExpandedInfo[section] { // expanded
            if let sections = notesFrc.sections {
                let currentSection = sections[section]
                return currentSection.numberOfObjects
            }
            return self.notesFrc.fetchedObjects?.count ?? 0
        } else { // collapsed
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionHeaderView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView") as! CollapsibleTableViewHeaderView
        var title = "No Category"
        if let sections = notesFrc.sections {
            let currentSection = sections[section]
            if !currentSection.name.isEmpty {
                title = currentSection.name
            }
        }
        sectionHeaderView.section = section
        sectionHeaderView.delegate = self
        sectionHeaderView.titleLabel.text = title
        sectionHeaderView.collapsed = sectionExpandedInfo[section]
        return sectionHeaderView;
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let label = UILabel(frame: CGRect(origin: .zero, size: CGSize(width: Int.max, height: Int.max)))
        label.text = "test"
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.sizeToFit()
        let height1 = label.frame.size.height

        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.sizeToFit()
        let height2 = label.frame.size.height

        return (height1 + height2) * 1.7
    }

    fileprivate func configureCell(_ cell: NoteTableViewCell, at indexPath: IndexPath) {
        let selectedBackgroundView = UIView(frame: cell.frame)
        selectedBackgroundView.backgroundColor = UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1.0) // set color here
        cell.selectedBackgroundView = selectedBackgroundView
        let note = self.notesFrc.object(at: indexPath)
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        cell.textLabel?.text = note.title
        cell.backgroundColor = .clear
        let date = Date(timeIntervalSince1970: note.modified)
        let dateFormat = DateFormatter()
        dateFormat.dateStyle = .short
        dateFormat.timeStyle = .none;
        dateFormat.doesRelativeDateFormatting = true
        cell.detailTextLabel?.text = dateFormat.string(from: date as Date)
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.indexPath = indexPath
        cell.categoryDelegate = self
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteTableViewCell
        configureCell(cell, at: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let note = self.notesFrc.object(at: indexPath)
            HUD.show(.progress)
            if note == self.editorViewController?.note {
                self.editorViewController?.note = nil
            }
            
            if let sections = notesFrc.sections {
                numberOfObjectsInCurrentSection = sections[indexPath.section].numberOfObjects
            }
            
            NotesManager.shared.delete(note: note, completion: { [weak self] in
//                var newIndex = 0
//                if indexPath.row >= 0 {
//                    newIndex = indexPath.row
//                }
//                let noteCount = self?.notesFrc.fetchedObjects?.count ?? 0
//                if newIndex >= noteCount {
//                    newIndex = noteCount - 1
//                }
//
//                if newIndex >= 0 && newIndex < noteCount {
//                    let newNote = self?.notesFrc.fetchedObjects?[newIndex]
//                    self?.editorViewController?.note = newNote
//                    DispatchQueue.main.async {
//                        self?.tableView.selectRow(at: IndexPath(row: newIndex, section: 0), animated: false, scrollPosition: .none)
//                    }
//                } else {
//                    self?.editorViewController?.note = nil
//                }
                //                    if self?.splitViewController?.displayMode == .primaryHidden {
                //                        //called while showing editor
                //                        self?.tableView.reloadData()
                //                    }
                HUD.hide()
            })
            tableView.endUpdates()
        }
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(NoteTableViewCell.selectCategory(sender:))
    }

    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
       //
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case detailSegueIdentifier:
            if let indexPath = tableView.indexPathForSelectedRow,
                let navigationController = segue.destination as? UINavigationController,
                let editorController = navigationController.topViewController as? EditorViewController {
                editorViewController = editorController
                let note = notesFrc.object(at: indexPath)
                editorController.note = note
                editorController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                editorController.navigationItem.leftItemsSupplementBackButton = true
                
                if splitViewController?.displayMode == .allVisible || splitViewController?.displayMode == .primaryOverlay {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.splitViewController?.preferredDisplayMode = .primaryHidden
                    }, completion: nil)
                }
            }
            
        case categorySegueIdentifier:
            let categories = notesFrc.fetchedObjects?.compactMap({ (note) -> String? in
                return note.category
            })
            if let navigationController = segue.destination as? UINavigationController,
                let categoryController = navigationController.topViewController as? CategoryTableViewController,
                let categories = categories,
                let indexPath = indexPathForCategory {
                categoryController.categories = categories.removingDuplicates()
                let note = notesFrc.object(at: indexPath)
                categoryController.note = note
            }
            
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func onRefresh(sender: Any?) {
        guard NotesManager.isOnline else {
            return
        }
        
        if let refreshControl = refreshControl, !refreshControl.isRefreshing {
            refreshControl.beginRefreshing()
            tableView.setContentOffset(CGPoint(x: 0, y: tableView.contentOffset.y - refreshControl.frame.size.height), animated: true)
        }
        addBarButton.isEnabled = false
        settingsBarButton.isEnabled = false
        NotesManager.shared.sync { [weak self] in
            self?.addBarButton.isEnabled = true
            self?.settingsBarButton.isEnabled = true
            self?.refreshControl?.endRefreshing()
            self?.tableView.reloadData()
        }
    }

    @IBAction func onSettings(sender: Any?) {
        let storyboard = UIStoryboard(name: "Main_iPhone", bundle:nil)
        var nav: UINavigationController?
        if sender as? UIBarButtonItem == settingsBarButton {
            nav = storyboard.instantiateViewController(withIdentifier: "login") as? UINavigationController
        } else {
            let loginController = storyboard.instantiateViewController(withIdentifier: "server")
            nav = UINavigationController(rootViewController: loginController)
            nav?.modalPresentationStyle = .formSheet
        }
        if let nav = nav {
            present(nav, animated: true, completion: nil)
        }
    }

    @IBAction func onAdd(sender: Any?) {
//        self.addingNote = YES;
//        self.editorViewController.addingNote = YES;
//        [[OCNotesHelper sharedHelper] addNote:@""];
        HUD.show(.progress)
        NotesManager.shared.add(content: "", category: "", completion: { [weak self] note in
//            self?.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: true, scrollPosition: .top)
            if note != nil {
                self?.performSegue(withIdentifier: detailSegueIdentifier, sender: self)
            }
            HUD.hide()
        })
    }
    
    private func configureFRC() -> NSFetchedResultsController<CDNote> {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.fetchBatchSize = 288
        request.predicate = NSPredicate(format: "cdDeleteNeeded == %@", NSNumber(value: false))
        request.sortDescriptors = [NSSortDescriptor(key: "cdCategory", ascending: true),
                                   NSSortDescriptor(key: "cdModified", ascending: false)]
        let frc = NSFetchedResultsController(fetchRequest: request,
                                             managedObjectContext: NotesData.mainThreadContext,
                                             sectionNameKeyPath: "cdCategory",
                                             cacheName: nil)
        frc.delegate = self
        try! frc.performFetch()
        if let sections = frc.sections {
            for _ in sections {
                sectionExpandedInfo.append(true)
            }
        }
        return frc
    }

    
    // MARK:  Notification Callbacks
    
    private func reachabilityChanged() {
        //
    }

    private func didBecomeActive() {
        if KeychainHelper.server.isEmpty {
            onSettings(sender: nil)
        } else if KeychainHelper.syncOnStart,
            NotesManager.isOnline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                NotesManager.shared.sync()
            })
        }
    }

    private func networkSuccess() {
        //
    }

    private func networkError() {
        //
    }

}

extension NotesTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        sectionExpandedInfoCount = sectionExpandedInfo.count
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch (type) {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                if numberOfObjectsInCurrentSection > 1 {
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } else {
                    tableView.deleteSections(NSIndexSet(index: indexPath.section) as IndexSet, with: .fade)
                }
            }

        case .update:
            if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) as? NoteTableViewCell {
                configureCell(cell, at: indexPath)
            }

        case .move:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
                if sectionExpandedInfoCount > sectionExpandedInfo.count {
                    print("A section was removed")
                    tableView.deleteSections(NSIndexSet(index: indexPath.section) as IndexSet, with: .fade)
                }
            }

            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .fade)
                if sectionExpandedInfoCount < sectionExpandedInfo.count {
                    print("A section was added")
                    tableView.insertSections(NSIndexSet(index: newIndexPath.section) as IndexSet, with: .fade)
                }
            }
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.sectionExpandedInfo.insert(true, at: sectionIndex)
        case .delete:
            self.sectionExpandedInfo.remove(at: sectionIndex)
        default:
            return
        }
    }
    
}

extension NotesTableViewController: UIActionSheetDelegate {
    
    
}

extension NotesTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        var predicate: NSPredicate?
        if let text = searchController.searchBar.text, !text.isEmpty {
            predicate = NSPredicate(format: "(cdTitle contains[c] %@) || (cdContent contains[cd] %@)", text, text)
        }
        notesFrc.fetchRequest.predicate = predicate
        do {
            try notesFrc.performFetch()
            tableView.reloadData()
        } catch { }
    }

}

extension NotesTableViewController: UISearchBarDelegate {
    
    
}

extension NotesTableViewController: UISplitViewControllerDelegate {
    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
        guard svc == self.splitViewController else {
            return
        }
        if displayMode == .allVisible || displayMode == .primaryOverlay {
            self.editorViewController?.noteView.resignFirstResponder()
        }
    }

    func targetDisplayModeForAction(in svc: UISplitViewController) -> UISplitViewController.DisplayMode {
        if svc.displayMode == .primaryHidden {
            if svc.traitCollection.horizontalSizeClass == .regular,
            [.landscapeLeft, .landscapeRight].contains(UIDevice.current.orientation) {
                return .allVisible
            }
            return .primaryOverlay
        }
        return .primaryHidden
    }

    override func collapseSecondaryViewController(_ secondaryViewController: UIViewController, for splitViewController: UISplitViewController) {
        self.editorViewController?.note = nil
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
}

extension NotesTableViewController: UITableViewDropDelegate {

    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
//        if (session.items.count > 0) {
//            if ([session hasItemsConformingToTypeIdentifiers:@[(NSString *)kUTTypeText, (NSString *)kUTTypeXML, (NSString *)kUTTypeHTML, (NSString *)kUTTypeJSON, (NSString *)kUTTypePlainText]]) {
//                return YES;
//            }
//        }
        return false
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
//        if (destinationIndexPath.row != 0) {
//            return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationForbidden intent:UITableViewDropIntentAutomatic];
//        } else {
//            return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCopy intent:UITableViewDropIntentInsertAtDestinationIndexPath];
//        }
        return UITableViewDropProposal(operation: .forbidden, intent: .automatic)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        //
//        for (UIDragItem *item in coordinator.session.items) {
//            [item.itemProvider loadDataRepresentationForTypeIdentifier:(NSString *)kUTTypeText completionHandler:^(NSData * _Nullable data, NSError * _Nullable error) {
//                NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//                [[OCNotesHelper sharedHelper] performSelectorOnMainThread:@selector(addNote:) withObject:content waitUntilDone:NO];
//                }];
//        }

    }

}

extension NotesTableViewController: NoteCategoryDelegate {
    
    func selectCategory(_ indexPath: IndexPath) {
        indexPathForCategory = indexPath
        self.performSegue(withIdentifier: "SelectCategorySegue", sender: self)
    }
    
}

extension NotesTableViewController: CollapsibleTableViewHeaderViewDelegate {
    func toggleSection(_ header: CollapsibleTableViewHeaderView, section: Int) {
        let index = header.section
        sectionExpandedInfo[index] = !sectionExpandedInfo[index]
        header.collapsed = sectionExpandedInfo[index]
        self.tableView.reloadSections(NSIndexSet(index: index) as IndexSet, with: .automatic)
    }
}

extension Array where Element: Equatable {
    func removingDuplicates() -> Array {
        return reduce(into: []) { result, element in
            if !result.contains(element) {
                result.append(element)
            }
        }
    }
}
