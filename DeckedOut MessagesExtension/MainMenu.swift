//
//  MainMenu.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 6/24/25.
//

import UIKit

final class MainMenuViewController: UIViewController {

    // MARK: – Properties
    private var deck           = Deck()
    private let label          = UILabel()
    private let cardImageView  = UIImageView()

    // MARK: – View Life-Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        deck.shuffle()

        configureLabel()
        configureImageView()
        configureDrawButton()
        layoutUI()
    }

    // MARK: – UI Setup
    private func configureLabel() {
        label.text = "Tap to draw a card"
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureImageView() {
        cardImageView.contentMode = .scaleAspectFit
        cardImageView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureDrawButton() {
        let button = UIButton(type: .system)
        button.setTitle("Draw Card", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        button.addTarget(self, action: #selector(drawCard), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func layoutUI() {
        view.addSubview(label)
        view.addSubview(cardImageView)

        NSLayoutConstraint.activate([
            cardImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            cardImageView.widthAnchor.constraint(equalToConstant: 80),
            cardImageView.heightAnchor.constraint(equalToConstant: 120),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: cardImageView.bottomAnchor, constant: 10)
        ])
    }

    // MARK: – Actions
    @objc private func drawCard() {
        guard let card = deck.drawCard() else {
            cardImageView.image = nil
            label.text = "No cards left!"
            return
        }

        let imageName = "\(card.rank.rawValue)\(card.suit.rawValue)" // e.g. "7Hearts"
        cardImageView.image = UIImage(named: imageName)
        label.text = imageName         // remove this line when you’re done debugging
    }
}
