//
//  NotesTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import CoreData
import MobileCoreServices
import PKHUD
import SwiftMessages
import UIKit

enum FrcDelegateUpdate {
    case disable
    case enable(withFetch: Bool)
}

let detailSegueIdentifier = "showDetail"
let categorySegueIdentifier = "SelectCategorySegue"

class NotesTableViewController: UITableViewController {

    @IBOutlet var addBarButton: UIBarButtonItem!
    @IBOutlet weak var refreshBarButton: UIBarButtonItem!
    @IBOutlet var settingsBarButton: UIBarButtonItem!

    var notes: [CDNote]?
    var searchController: UISearchController?
    var editorViewController: EditorViewController?
    
    private var networkHasBeenUnreachable = false
    private var searchResult: [CDNote]?
    private var numberOfObjectsInCurrentSection = 0

    private lazy var notesFrc: NSFetchedResultsController<CDNote> = configureFRC()

    private var observers = [NSObjectProtocol]()
    private var sectionCollapsedInfo = ExpandableSectionType()
    private var isSyncing = false
    private var noteToAddOnViewDidLoad: String?

    private var contextMenuIndexPath: IndexPath?
    
    private var dateFormat: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none;
        df.doesRelativeDateFormatting = true
        return df
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        clearsSelectionOnViewWillAppear = false

        self.observers.append(NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        self?.tableView.reloadData()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
                                                                        self?.didBecomeActive()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .offlineModeChanged,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
                                                                        self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
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
        self.observers.append(NotificationCenter.default.addObserver(forName: .doneSelectingCategory,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
                                                                        self?.tableView.reloadData()
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .networkSuccess,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] _ in
                                                                        HUD.hide()
                                                                        self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
                                                                        self?.addBarButton.isEnabled = true
                                                                        self?.settingsBarButton.isEnabled = true
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: .networkError,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { [weak self] notification in
                                                                        HUD.hide()
                                                                        self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
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

        let nib = UINib(nibName: "CollapsibleTableViewHeaderView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "HeaderView")
        #if targetEnvironment(macCatalyst)
        navigationController?.navigationBar.isHidden = true
        #else
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.toolbar.isTranslucent = true
        navigationController?.toolbar.clipsToBounds = true
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.hidesNavigationBarDuringPresentation = true
        searchController?.searchBar.delegate = self
        searchController?.searchBar.sizeToFit()
        updateFrcDelegate(update: .enable(withFetch: true))
        tableView.tableHeaderView = searchController?.searchBar
        #endif

        sectionCollapsedInfo = KeychainHelper.sectionExpandedInfo
        
        tableView.contentOffset = CGPoint(x: 0, y: searchController?.searchBar.frame.size.height ?? 0.0 + tableView.contentOffset.y)
        tableView.backgroundView = UIView()
        tableView.dropDelegate = self
        updateSectionExpandedInfo()
        if let noteToAddOnViewDidLoad = noteToAddOnViewDidLoad {
            addNote(content: noteToAddOnViewDidLoad)
            self.noteToAddOnViewDidLoad = nil
        }
        tableView.reloadData()
        definesPresentationContext = true
        refreshBarButton.isEnabled = NoteSessionManager.isOnline
        #if !targetEnvironment(macCatalyst)
        tableView.backgroundColor = .ph_backgroundColor
        #endif
        if let splitVC = splitViewController as? PBHSplitViewController {
            splitVC.notesTableViewController = self
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addBarButton.isEnabled = true
        settingsBarButton.isEnabled = true
        refreshBarButton.isEnabled = NoteSessionManager.isOnline
    }
    
    // MARK: - Public functions
    
    func updateFrcDelegate(update: FrcDelegateUpdate) {
        switch update {
        case .disable:
            notesFrc.delegate = nil
        case .enable(let withFetch):
            notesFrc.delegate = self
            if withFetch {
                do {
                    try notesFrc.performFetch()
                    tableView.reloadData()
                } catch { }
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let sections = notesFrc.sections {
            return sections.count
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var title = ""
        if let sections = notesFrc.sections {
            let currentSection = sections[section]
            if !currentSection.name.isEmpty {
                title = currentSection.name
            }
            let collapsed = sectionCollapsedInfo.first(where: { $0.title == title })?.collapsed ?? false
            if !collapsed { // expanded
                return currentSection.numberOfObjects
            } else { // collapsed
                return 0
            }
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        #if targetEnvironment(macCatalyst)
//        return nil
//        #endif
        let sectionHeaderView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView") as! CollapsibleTableViewHeaderView
        var displayTitle = ""
        var title = ""
        if let sections = notesFrc.sections {
            let currentSection = sections[section]
            if !currentSection.name.isEmpty {
                displayTitle = currentSection.name
            }
            title = currentSection.name
        }
        sectionHeaderView.sectionTitle = title
        sectionHeaderView.sectionIndex = section
        sectionHeaderView.delegate = self
        sectionHeaderView.titleLabel.text = displayTitle
        sectionHeaderView.collapsed = sectionCollapsedInfo.first(where: { $0.title == title })?.collapsed ?? false
        return sectionHeaderView
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
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
        guard notesFrc.validate(indexPath: indexPath) else {
            return
        }
        #if targetEnvironment(macCatalyst)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17)
        cell.textLabel?.textColor = nil
        #else
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        cell.backgroundColor = .ph_cellBackgroundColor
        cell.contentView.backgroundColor = .ph_cellBackgroundColor
        let selectedBackgroundView = UIView(frame: cell.frame)
        selectedBackgroundView.backgroundColor = UIColor.ph_cellSelectionColor
        cell.selectedBackgroundView = selectedBackgroundView
        #endif

        let note = self.notesFrc.object(at: indexPath)
        cell.textLabel?.text = note.title
        cell.backgroundColor = .clear
        let date = Date(timeIntervalSince1970: note.modified)
        cell.detailTextLabel?.text = dateFormat.string(from: date as Date)
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteTableViewCell
        configureCell(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Use context menu on iOS 13 and above
        if #available(iOS 13.0, *) {
            return nil
        }
        // Currently only NextCloud supports categories
        if !KeychainHelper.isNextCloud {
            return nil
        }
        var actions = [UIContextualAction]()
        let title = NSLocalizedString("Category", comment: "Name of cell category action")
        let categoryAction = UIContextualAction(style: .normal,
                                                title: title,
                                                handler: { [weak self] (_, _, completionHandler) in
                                                    self?.showCategories(indexPath: indexPath)
                                                    completionHandler(true)
        })
        actions.append(categoryAction)
        
        if KeychainHelper.notesApiVersion != Router.defaultApiVersion {
            let renameAction = UIContextualAction(style: .normal,
                                                  title: NSLocalizedString("Rename", comment: "Action to change title of a note"),
                                                  handler: { [weak self] (_, _, completionHandler) in
                                                    self?.showRenameAlert(for: indexPath)
                                                    completionHandler(true)
            })
            actions.append(renameAction)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: actions)
        return configuration
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
            
            NoteSessionManager.shared.delete(note: note, completion: { [weak self] in
                if self?.notesFrc.validate(indexPath: indexPath) ?? false {
                    var newIndex = 0
                    if indexPath.row >= 0 {
                        newIndex = indexPath.row
                    }
                    var noteCount = 0
                    if let sections = self?.notesFrc.sections,
                        sections.count >= indexPath.section {
                        noteCount = sections[indexPath.section].numberOfObjects
                    }
                    if newIndex >= noteCount {
                        newIndex = noteCount - 1
                    }

                    if newIndex >= 0 && newIndex < noteCount,
                        let newNote = self?.notesFrc.sections?[indexPath.section].objects?[newIndex] as? CDNote {
                        self?.editorViewController?.note = newNote
                        DispatchQueue.main.async {
                            self?.tableView.selectRow(at: IndexPath(row: newIndex, section: indexPath.section), animated: false, scrollPosition: .none)
                        }
                    } else {
                        self?.editorViewController?.note = nil
                    }
                }
                HUD.hide()
            })
        }
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case detailSegueIdentifier:
            var selectedIndexPath = IndexPath(row: 0, section: 0)
            if let cell = sender as? UITableViewCell, let cellIndexPath = tableView.indexPath(for: cell) {
                selectedIndexPath = cellIndexPath
            }
            if let navigationController = segue.destination as? UINavigationController,
                let editorController = navigationController.topViewController as? EditorViewController {
                editorViewController = editorController
                let note = notesFrc.object(at: selectedIndexPath)
                editorController.note = note
                editorController.isNewNote = false
                #if !targetEnvironment(macCatalyst)
                editorController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                editorController.navigationItem.leftItemsSupplementBackButton = true
                if splitViewController?.displayMode == .allVisible || splitViewController?.displayMode == .primaryOverlay {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.splitViewController?.preferredDisplayMode = .primaryHidden
                    }, completion: nil)
                }
                #endif
            }
            
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        #if !targetEnvironment(macCatalyst)
        tableView.deselectRow(at: indexPath, animated: true)
        #endif
        editorViewController?.isNewNote = false
    }

    private func showRenameAlert(for indexPath: IndexPath) {
        var nameTextField: UITextField?
        let note = self.notesFrc.object(at: indexPath)
        let alertController = UIAlertController(title: NSLocalizedString("Note Title", comment: "Title of alert to change title"),
                                                message: NSLocalizedString("Rename the note", comment: "Message of alert to change title"),
                                                preferredStyle: .alert)
        alertController.addTextField { textField in
            nameTextField = textField
            textField.text = note.title
            textField.keyboardType = .default
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Caption of Cancel button"), style: .cancel, handler: nil)
        let renameAction = UIAlertAction(title: NSLocalizedString("Rename", comment: "Caption of Rename button"), style: .default) { (action) in
            guard let newName = nameTextField?.text,
                !newName.isEmpty,
                newName != note.title else {
                    return
            }
            note.title = newName
            NoteSessionManager.shared.update(note: note, completion: nil)
        }
        alertController.addAction(cancelAction)
        alertController.addAction(renameAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @available(iOS 13.0, *)
    public override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard notesFrc.validate(indexPath: indexPath) else {
            return nil
        }
        contextMenuIndexPath = indexPath
        let note = self.notesFrc.object(at: indexPath)
        var actions = [UIAction]()

        if KeychainHelper.isNextCloud,
        KeychainHelper.notesApiVersion != Router.defaultApiVersion {
            let renameAction = UIAction(title: NSLocalizedString("Rename...", comment: "Action to change title of a note"), image: UIImage(systemName: "square.and.pencil")) { [weak self] action in
                self?.showRenameAlert(for: indexPath)
            }
            actions.append(renameAction)
        }
        if KeychainHelper.isNextCloud {
            let categoryAction = UIAction(title: NSLocalizedString("Category...", comment: "Action to change category of a note"), image: UIImage(named: "categories")) { [weak self] _ in
                self?.showCategories(indexPath: indexPath)
            }
            actions.append(categoryAction)
        }
        let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] action in
            guard let self = self,
                !note.content.isEmpty else {
                    return
            }
            let noteExporter = PBHNoteExporter(title: note.title, text: note.content, viewController: self, from: CGRect(origin: point, size: CGSize(width: 3, height: 3)), in: tableView)
            noteExporter.showMenu()
        }
        actions.append(shareAction)

        let deleteAction = UIAction(title: NSLocalizedString("Delete", comment: "Action to delete a note"), image: (UIImage(systemName: "trash")), identifier: UIAction.Identifier("deleteAction"), discoverabilityTitle: nil, attributes: .destructive, state: .off, handler: { [weak self] _ in
            self?.tableView(tableView, commit: .delete, forRowAt: indexPath)
        })
        actions.append(deleteAction)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ -> UIMenu? in
            return UIMenu(title: "", children: actions)
        }
        
    }
    
    @IBAction func onRefresh(sender: Any?) {
        guard NoteSessionManager.isOnline else {
            return
        }

        refreshBarButton.isEnabled = false
        addBarButton.isEnabled = false
        settingsBarButton.isEnabled = false
        isSyncing = true
        NoteSessionManager.shared.sync { [weak self] in
            self?.isSyncing = false
            self?.addBarButton.isEnabled = true
            self?.settingsBarButton.isEnabled = true
            self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
            self?.tableView.reloadData()
        }
    }

    @IBAction func onSettings(sender: Any?) {
        let storyboard = UIStoryboard(name: "Settings", bundle:nil)
        var nav: UINavigationController?
        if sender as? UIBarButtonItem == settingsBarButton {
            nav = storyboard.instantiateViewController(withIdentifier: "login") as? UINavigationController
        } else {
            let loginController = storyboard.instantiateViewController(withIdentifier: "LoginTableViewController")
            nav = UINavigationController(rootViewController: loginController)
            nav?.modalPresentationStyle = .formSheet
        }
        if let nav = nav {
            present(nav, animated: true, completion: nil)
        }
    }

    @IBAction func onAdd(sender: Any?) {
        addNote(content: "")
    }
    
    func addNote(content: String) {
        guard isViewLoaded else {
            noteToAddOnViewDidLoad = content
            return
        }
        HUD.show(.progress)
        NoteSessionManager.shared.add(content: content, category: "", completion: { [weak self] note in
            if note != nil {
                let indexPath = IndexPath(row: 0, section: 0)
                if self?.notesFrc.validate(indexPath: indexPath) ?? false,
                    let collapsedInfo = self?.sectionCollapsedInfo.first(where: { $0.title == Constants.noCategory }),
                    !collapsedInfo.collapsed {
                    self?.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
                }
                self?.editorViewController?.isNewNote = true
                self?.performSegue(withIdentifier: detailSegueIdentifier, sender: self)
            }
            HUD.hide()
        })
    }
    
    private func configureFRC() -> NSFetchedResultsController<CDNote> {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.fetchBatchSize = 288
        request.predicate = .allNotes
        request.sortDescriptors = [NSSortDescriptor(key: "cdCategory", ascending: true),
                                   NSSortDescriptor(key: "cdModified", ascending: false)]
        let frc = NSFetchedResultsController(fetchRequest: request,
                                             managedObjectContext: NotesData.mainThreadContext,
                                             sectionNameKeyPath: "sectionName",
                                             cacheName: nil)
        return frc
    }

    func updateSectionExpandedInfo() {
        let knownSectionTitles = Set(sectionCollapsedInfo.map({ $0.title }))
        if let sections = notesFrc.sections {
            if sections.count > 0 {
                let newSectionTitles = Set(sections.map({ $0.name }))
                let deleted = knownSectionTitles.subtracting(newSectionTitles)
                let added = newSectionTitles.subtracting(knownSectionTitles)
                sectionCollapsedInfo = sectionCollapsedInfo.filter({ !deleted.contains($0.title) })
                for newSection in added {
                    sectionCollapsedInfo.append(ExpandableSection(title: newSection, collapsed: false))
                }
            } else {
                sectionCollapsedInfo.removeAll()
            }
            KeychainHelper.sectionExpandedInfo = sectionCollapsedInfo
        }
    }
    
    // MARK:  Notification Callbacks
    
    private func reachabilityChanged() {
        //
    }

    private func didBecomeActive() {
        if KeychainHelper.server.isEmpty {
            onSettings(sender: nil)
        } else if KeychainHelper.syncOnStart {
            onRefresh(sender: nil)
        } else if KeychainHelper.dbReset {
            CDNote.reset()
            KeychainHelper.dbReset = false
            try? notesFrc.performFetch()
            tableView.reloadData()
        }
    }
    
    fileprivate func showCategories(indexPath: IndexPath) {
        let categories = notesFrc.fetchedObjects?.compactMap({ (note) -> String? in
            return note.category
        })
        //        AppDelegate.shared.changeCategory()
        let storyboard = UIStoryboard(name: "Categories", bundle: Bundle.main)
        if let navController = storyboard.instantiateViewController(withIdentifier: "CategoryNavigationController") as? UINavigationController,
            let categoryController = navController.topViewController as? CategoryTableViewController,
            let categories = categories {
            let note = self.notesFrc.object(at: indexPath)
            categoryController.categories = categories.removingDuplicates()
            if let section = self.notesFrc.sections?.first(where: { $0.name == note.category }) {
                self.numberOfObjectsInCurrentSection = section.numberOfObjects
            }
            categoryController.note = note
            self.present(navController, animated: true, completion: nil)
        }
    }
    
}

extension NotesTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("Starting update")
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let note = anObject as? CDNote else {
            return
        }
        let sectionName = note.category == "" ? Constants.noCategory : note.category
        switch (type) {
        case .insert:
            if let newIndexPath = newIndexPath {
                if let collapsedInfo = sectionCollapsedInfo.first(where: { $0.title == sectionName }) {
                    if !collapsedInfo.collapsed {
                        tableView.insertRows(at: [newIndexPath], with: .fade)
                    }
                }
            }
        case .delete:
            if let indexPath = indexPath {
                if let collapsedInfo = sectionCollapsedInfo.first(where: { $0.title == sectionName }) {
                    if !collapsedInfo.collapsed {
                        if isSyncing {
                            tableView.deleteRows(at: [indexPath], with: .fade)
                        } else if numberOfObjectsInCurrentSection > 1 {
                            print("Deleting row")
                            tableView.deleteRows(at: [indexPath], with: .fade)
                        }
                    }
                }
            }
        case .update:
            if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) as? NoteTableViewCell {
                configureCell(cell, at: indexPath)
            }
        case .move:
            print("IndexPath \(String(describing: indexPath)) newIndexPath \(String(describing: newIndexPath))")
            if let indexPath = indexPath, let sectionCount = controller.sections?.count {
                if indexPath.section < sectionCount, let oldSection = controller.sections?[indexPath.section] {
                    let oldSectionName = oldSection.name
                    if let collapsedInfo = sectionCollapsedInfo.first(where: { $0.title == oldSectionName }) {
                        if !collapsedInfo.collapsed {
                            tableView.deleteRows(at: [indexPath], with: .fade)
                        }
                    }
                }
            }
            if let newIndexPath = newIndexPath {
                if let collapsedInfo = sectionCollapsedInfo.first(where: { $0.title == sectionName }) {
                    if !collapsedInfo.collapsed {
                        tableView.insertRows(at: [newIndexPath], with: .fade)
                    }
                }
            }
        @unknown default:
            fatalError()
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            print("Inserting section at index \(sectionIndex)")
            tableView.insertSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
            sectionCollapsedInfo.append(ExpandableSection(title: sectionInfo.name, collapsed: false))
        case .delete:
            print("Deleting section at index \(sectionIndex)")
            tableView.deleteSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
            sectionCollapsedInfo = sectionCollapsedInfo.filter({ $0.title != sectionInfo.name })
            numberOfObjectsInCurrentSection = 0
        default:
            return
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        updateSectionExpandedInfo()
        print("Ending update")
    }

}

extension NotesTableViewController: UIActionSheetDelegate {
    
    
}

extension NotesTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        var predicate: NSPredicate?
        if let text = searchController.searchBar.text, !text.isEmpty {
            let matchingText = NSPredicate(format: "(cdTitle contains[c] %@) || (cdContent contains[cd] %@)", text, text)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [.allNotes, matchingText])
        } else {
            predicate = .allNotes
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

extension NotesTableViewController: UITableViewDropDelegate {

    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        if !session.items.isEmpty,
            session.hasItemsConforming(toTypeIdentifiers: [kUTTypeText as String,
                                                           kUTTypeXML as String,
                                                           kUTTypeHTML as String,
                                                           kUTTypeJSON as String,
                                                           kUTTypePlainText as String]) {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if destinationIndexPath?.section != 0 {
            return UITableViewDropProposal(operation: .forbidden, intent: .automatic)
        } else {
            return UITableViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
        }
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        for item in coordinator.session.items {
            item.itemProvider.loadDataRepresentation(forTypeIdentifier: kUTTypeText as String) { (data, _) in
                if let contentData = data,
                    let content = String(bytes: contentData, encoding: .utf8) {
                        NoteSessionManager.shared.add(content: content, category: "")
                }
            }
        }
    }

}

extension NotesTableViewController: CollapsibleTableViewHeaderViewDelegate {
    func toggleSection(_ header: CollapsibleTableViewHeaderView, sectionTitle: String, sectionIndex: Int) {
        if  let info = sectionCollapsedInfo.first(where: { $0.title == sectionTitle }),
            let index = sectionCollapsedInfo.firstIndex(where: { $0.title == sectionTitle }) {
            let collapsed = info.collapsed
            sectionCollapsedInfo.remove(at: index)
            sectionCollapsedInfo.insert(ExpandableSection(title: info.title, collapsed: !collapsed), at: index)
            KeychainHelper.sectionExpandedInfo = sectionCollapsedInfo
            header.collapsed = !collapsed
            self.tableView.reloadSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .automatic)
        }
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

extension NSFetchedResultsController {
    
    @objc func validate(indexPath: IndexPath) -> Bool {
        if let sections = self.sections {
            if indexPath.section >= sections.count {
                return false
            }
            
            if indexPath.row >= sections[indexPath.section].numberOfObjects {
                return false
            }
        }
        return true
    }
    
}

private extension NSPredicate {
    
    static var allNotes: NSPredicate {
        return NSPredicate(format: "cdDeleteNeeded == %@", NSNumber(value: false))
    }
    
}
