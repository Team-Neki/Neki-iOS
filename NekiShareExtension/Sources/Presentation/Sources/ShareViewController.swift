//
//  ShareViewController.swift
//  NekiShareExtension
//
//  Created by SwainYun on 3/13/26.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

enum ShareViewControllerError: Error {
    case noInputItems
    case invalidConfiguration
    case tooManyImages
    case loadPreviewFailed
}

final class ShareViewController: UIViewController {
    private let containerView = UIView()
    private let navigationBar = UINavigationBar()
    private let imageView = UIImageView()
    private let countBadgeLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    private var validImageProviders: [NSItemProvider] = []
    private let maxImageCount: Int = 10
    
    private let configuration = ShareExtensionConfiguration()
    private lazy var processor: ImageShareUseCase = {
        let repository = FileManagerExtensionImageRepository(appGroupID: configuration.appGroupID)
        return ImageShareProcessor(repository: repository)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        
        Task { await prepareContent() }
    }
}


// MARK: - UI Related

private extension ShareViewController {
    func setupUI() {
        view.isOpaque = false
        
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.setContentCompressionResistancePriority(.required, for: .vertical)
        navigationBar.setContentHuggingPriority(.required, for: .vertical)
        let navigationItem = UINavigationItem(title: "네키로 사진 공유")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "취소", style: .plain, target: self, action: #selector(cancelAction))
        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "올리기", style: .prominent, target: self, action: #selector(postAction))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "올리기", style: .done, target: self, action: #selector(postAction))
        }
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationBar.setItems([navigationItem], animated: false)
        containerView.addSubview(navigationBar)
        
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(activityIndicator)
        
        countBadgeLabel.backgroundColor = .systemBlue.withAlphaComponent(0.9)
        countBadgeLabel.textColor = .white
        countBadgeLabel.font = .boldSystemFont(ofSize: 14)
        countBadgeLabel.textAlignment = .center
        countBadgeLabel.layer.cornerRadius = 14
        countBadgeLabel.clipsToBounds = true
        countBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(countBadgeLabel)
    }
    
    func setupLayout() {
        NSLayoutConstraint.activate([
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            
            navigationBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            imageView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            activityIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            
            countBadgeLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
            countBadgeLabel.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 8),
            countBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            countBadgeLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
}


// MARK: - Helper Methods

private extension ShareViewController {
    @objc func cancelAction() {
        let error = NSError(domain: "ShareExtension", code: NSUserCancelledError)
        extensionContext?.cancelRequest(withError: error)
    }
    
    @objc func postAction() {
        guard let deepLinkURL = configuration.deepLinkURL else { return cancelRequest(with: ShareViewControllerError.invalidConfiguration) }
        navigationBar.items?.first?.rightBarButtonItem?.isEnabled = false
        activityIndicator.startAnimating()
        
        Task {
            do {
                try await processor.share(providers: validImageProviders)
                await MainActor.run { openMainApp(with: deepLinkURL) }
            } catch {
                await MainActor.run { cancelRequest(with: error) }
            }
        }
    }
    
    @MainActor
    func prepareContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return cancelRequest(with: ShareViewControllerError.noInputItems) }
        validImageProviders = processor.extractImageProviders(from: items)
        let count = validImageProviders.count
        
        guard count > .zero else { return cancelRequest(with: ShareViewControllerError.noInputItems) }
        
        let isOverLimit = count > maxImageCount
        countBadgeLabel.text = isOverLimit ? "10+" : "\(count)"
        countBadgeLabel.textColor = isOverLimit ? .systemRed.withAlphaComponent(0.9) : .label
        countBadgeLabel.isHidden = count < 2
        navigationBar.items?.first?.rightBarButtonItem?.isEnabled = !isOverLimit
        
        if let firstProvider = validImageProviders.first {
            activityIndicator.startAnimating()
            
            do {
                let previewData = try await processor.fetchPreviewData(from: firstProvider)
                imageView.image = UIImage(data: previewData)
            } catch {
                imageView.image = nil
                navigationBar.items?.first?.rightBarButtonItem?.isEnabled = false
            }
            
            activityIndicator.stopAnimating()
        }
    }
    
    func cancelRequest(with error: Error) { extensionContext?.cancelRequest(withError: error) }
    
    func openMainApp(with url: URL) {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url)
                break
            }
            responder = responder?.next
        }
        self.extensionContext?.completeRequest(returningItems: [])
    }
}
