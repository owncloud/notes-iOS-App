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

    /*
 @property (nonatomic, strong) OCEditorViewController *editorViewController;
 @property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsBarButton;
 @property (strong, nonatomic) IBOutlet UIBarButtonItem *addBarButton;
     @property (strong, nonatomic) UISearchController *searchController;
     @property (nonatomic, copy) NSArray *ocNotes;

     
     NSArray *searchResults;

    
 - (IBAction) doRefresh:(id)sender;
 - (IBAction)doAdd:(id)sender;
*/

    @IBOutlet var addBarButton: UIBarButtonItem!
    @IBOutlet var settingsBarButton: UIBarButtonItem!

    static var notesRefreshControl: UIRefreshControl {
        let rControl = UIRefreshControl()
        rControl.tintColor =  UIColor(red: 0.13, green: 0.145, blue: 0.16, alpha: 1.0)
        rControl.addTarget(self, action: Selector(("onRefresh:")), for: .valueChanged)
        return rControl
    }

    var networkHasBeenUnreachable = false
    var addingNote = false

    private lazy var notesFrc: NSFetchedResultsController<CDNote> = configureFRC()

    var notes: [CDNote]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.clearsSelectionOnViewWillAppear = false
        self.refreshControl = NotesTableViewController.notesRefreshControl
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        
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
         
         //remove bottom line/shadow
         for (UIView *view in self.navigationController.navigationBar.subviews) {
         for (UIView *view2 in view.subviews) {
         if ([view2 isKindOfClass:[UIImageView class]]) {
         if (![view2.superview isKindOfClass:[UIButton class]]) {
         [view2 removeFromSuperview];
         }
         }
         }
         }
         self.navigationController.navigationBar.translucent = YES;
         self.navigationController.toolbar.translucent = YES;
         self.navigationController.toolbar.clipsToBounds = YES;
         self.splitViewController.delegate = self;
         self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
         self.searchController.searchResultsUpdater = self;
         self.searchController.hidesNavigationBarDuringPresentation = YES;
         self.searchController.dimsBackgroundDuringPresentation = NO;
         self.searchController.searchBar.delegate = self;
         [self.searchController.searchBar sizeToFit];
         self.searchController.searchBar.tintColor = [UIColor colorWithRed:0.12 green:0.18 blue:0.26 alpha:1.0];
         self.searchController.searchBar.barTintColor = [UIColor colorWithRed:0.957 green:0.957 blue:0.957 alpha:0.95];
         self.searchController.searchBar.backgroundImage = [UIImage new];
         self.tableView.tableHeaderView = self.searchController.searchBar;
         
         [self.tableView setContentOffset:CGPointMake(0, self.searchController.searchBar.frame.size.height + self.tableView.contentOffset.y)];
         
         if (@available(iOS 11.0, *)) {
         self.tableView.dropDelegate = self;
         }
         self.definesPresentationContext = YES;
 
*/
        
        
        
        
        
        
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
        //
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

@available(iOS 11.0, *)
extension NotesTableViewController: UITableViewDropDelegate {
   
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        //
    }
    
    
}
