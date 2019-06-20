//
//  NotesTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit
import CoreData

class NotesTableViewController: UITableViewController {

    @IBOutlet var addBarButton: UIBarButtonItem!
    @IBOutlet var settingsBarButton: UIBarButtonItem!

    var notes: [CDNote]?
    var addingNote = false
    var searchController: UISearchController?
    var editorViewController: EditorViewController?

    private var networkHasBeenUnreachable = false
    private var searchResult: [CDNote]?
    
    private lazy var notesFrc: NSFetchedResultsController<CDNote> = configureFRC()

    
    override func viewDidLoad() {
        super.viewDidLoad()

        clearsSelectionOnViewWillAppear = false
        refreshControl?.tintColor = UIColor(red: 0.13, green: 0.145, blue: 0.16, alpha: 1.0)
        
/*
         [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(reachabilityChanged:)
         name:AFNetworkingReachabilityDidChangeNotification
         object:nil];
         
         [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(didBecomeActive:)
         name:UIApplicationDidBecomeActiveNotification
         object:nil];
         
         [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(networkSuccess:)
         name:@"NetworkSuccess"
         object:nil];
         
         [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(networkError:)
         name:@"NetworkError"
         object:nil];
         
         [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(doRefresh:)
         name:@"SyncNotes"
         object:nil];
         
         [[NSNotificationCenter defaultCenter] addObserver:self
         selector:@selector(preferredContentSizeChanged:)
         name:UIContentSizeCategoryDidChangeNotification
         object:nil];
         
         [NSNotificationCenter.defaultCenter addObserver:self
         selector:@selector(reloadNotes:)
         name:FCModelChangeNotification
         object:OCNote.class];
         
         [NSNotificationCenter.defaultCenter addObserver:self
         selector:@selector(noteDeleted:)
         name:@"DeletingNote"
         object:nil];
         
         [OCNotesHelper sharedHelper];
         [self reloadNotes:nil];
*/
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
        definesPresentationContext = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didBecomeActive()
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.notesFrc.fetchedObjects?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath)
        
        let selectedBackgroundView = UIView(frame: cell.frame)
        selectedBackgroundView.backgroundColor = UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1.0) // set color here
        cell.selectedBackgroundView = selectedBackgroundView
        cell.tag = indexPath.row
        
        //        if (self.searchController.active) {
        //            note = [searchResults objectAtIndex:indexPath.row];
        //        } else {
        if let note = self.notesFrc.fetchedObjects?[indexPath.row] {
            //        }
            cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
            cell.textLabel?.text = note.title
            cell.backgroundColor = .clear
            if let date = note.modified {
                let dateFormat = DateFormatter()
                dateFormat.dateStyle = .short
                dateFormat.timeStyle = .none;
                dateFormat.doesRelativeDateFormatting = true
                cell.detailTextLabel?.text = dateFormat.string(from: date as Date)
                cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
            }
        }
        
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func onRefresh(sender: Any?) {
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
    }
    
    private func configureFRC() -> NSFetchedResultsController<CDNote> {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.fetchBatchSize = 288
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        let frc = NSFetchedResultsController(fetchRequest: request,
                                             managedObjectContext: NotesData.mainThreadContext,
                                             sectionNameKeyPath: nil, cacheName: nil)
        frc.delegate = self
        try! frc.performFetch()
        return frc
    }

    
    // MARK:  Notification Callbacks
    
    private func reachabilityChanged() {
        //
    }

    private func didBecomeActive() {
        if KeychainHelper.server.isEmpty {
            onSettings(sender: nil)
        } else if KeychainHelper.syncOnStart {
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
    
    
}

extension NotesTableViewController: UIActionSheetDelegate {
    
    
}

extension NotesTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        //
    }
    
    
    
}


extension NotesTableViewController: UISearchBarDelegate {
    
    
}

extension NotesTableViewController: UISplitViewControllerDelegate {
    
    
}

extension NotesTableViewController: UITableViewDropDelegate {
   
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        //
    }

}
