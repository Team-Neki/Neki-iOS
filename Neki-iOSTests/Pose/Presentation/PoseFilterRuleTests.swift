//
//  PoseFilterRuleTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/11/26.
//

import Testing
@testable import Neki_iOS

struct PoseFilterRuleTests {
    @Test("관계 태그를 고르면 인원수가 2인으로 선택된다", arguments: PoseRelation.allCases)
    func toggleRelation_selectsDuo(relation: PoseRelation) {
        var state = PoseFeature.State()

        state.toggleRelationFilter(relation)

        #expect(state.selectedCountFilterOption == .duo)
        #expect(state.selectedRelationFilterOption == relation)
    }

    @Test("3인을 고른 상태에서 커플을 고르면 2인으로 바뀐다")
    func toggleRelation_whileTrio_switchesToDuo() {
        var state = PoseFeature.State()
        state.togglePeopleCountFilter(.trio)

        state.toggleRelationFilter(.couple)

        #expect(state.selectedCountFilterOption == .duo)
        #expect(state.selectedRelationFilterOption == .couple)
    }

    @Test("같은 관계 태그를 다시 누르면 관계만 해제되고 2인은 남는다")
    func toggleSameRelation_clearsRelationOnly() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)

        state.toggleRelationFilter(.friend)

        #expect(state.selectedRelationFilterOption == nil)
        #expect(state.selectedCountFilterOption == .duo)
    }

    @Test("다른 관계 태그를 고르면 관계만 바뀌고 2인은 남는다")
    func toggleOtherRelation_replacesRelationOnly() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)

        state.toggleRelationFilter(.crush)

        #expect(state.selectedRelationFilterOption == .crush)
        #expect(state.selectedCountFilterOption == .duo)
    }

    @Test("관계를 고른 상태에서 2인이 아닌 인원수를 고르면 관계가 해제된다", arguments: [PeopleCountOption.solo, .trio, .quartet])
    func selectOtherPeopleCount_whileRelation_clearsRelation(option: PeopleCountOption) {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.couple)

        state.togglePeopleCountFilter(option)

        #expect(state.selectedCountFilterOption == option)
        #expect(state.selectedRelationFilterOption == nil)
    }

    @Test("관계를 고른 상태에서 2인을 다시 눌러 해제하면 관계도 해제된다")
    func deselectDuo_whileRelation_clearsRelation() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.couple)

        state.togglePeopleCountFilter(.duo)

        #expect(state.selectedCountFilterOption == nil)
        #expect(state.selectedRelationFilterOption == nil)
    }

    @Test("북마크를 켠 상태에서 관계 태그를 고르면 북마크가 꺼지고 2인과 관계가 선택된다")
    func toggleRelation_whileBookmark_turnsBookmarkOff() {
        var state = PoseFeature.State()
        state.toggleBookmarkFilter()

        state.toggleRelationFilter(.friend)

        #expect(state.isSelectedScrap == false)
        #expect(state.selectedCountFilterOption == .duo)
        #expect(state.selectedRelationFilterOption == .friend)
    }

    @Test("관계를 고른 상태에서 북마크를 누르면 인원수와 관계가 비워진다")
    func toggleBookmark_whileRelation_clearsPeopleCountAndRelation() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)

        state.toggleBookmarkFilter()

        #expect(state.isSelectedScrap)
        #expect(state.selectedCountFilterOption == nil)
        #expect(state.selectedRelationFilterOption == nil)
    }

    @Test("북마크를 켠 상태에서 인원수를 고르면 북마크가 꺼지고, 같은 인원수를 다시 고르면 해제된다")
    func togglePeopleCount_whileBookmark_turnsBookmarkOffThenDeselects() {
        var state = PoseFeature.State()
        state.toggleBookmarkFilter()

        state.togglePeopleCountFilter(.trio)

        #expect(state.isSelectedScrap == false)
        #expect(state.selectedCountFilterOption == .trio)

        state.togglePeopleCountFilter(.trio)

        #expect(state.selectedCountFilterOption == nil)
    }

    @Test("2인을 고른 상태에서 관계 태그를 고르거나 바꾸거나 해제하면 서버에 보낼 목록 조건이 바뀐다")
    func relationChanges_changeListCondition() {
        var state = PoseFeature.State()
        state.togglePeopleCountFilter(.duo)
        var filters = [state.listCondition.filter]

        state.toggleRelationFilter(.friend)
        filters.append(state.listCondition.filter)
        state.toggleRelationFilter(.couple)
        filters.append(state.listCondition.filter)
        state.toggleRelationFilter(.couple)
        filters.append(state.listCondition.filter)

        #expect(filters == [
            PoseListFilter(peopleCount: .duo),
            PoseListFilter(peopleCount: .duo, relation: .friend),
            PoseListFilter(peopleCount: .duo, relation: .couple),
            PoseListFilter(peopleCount: .duo)
        ])
    }

    @Test("지금 조건의 첫 페이지를 받기 전에는 포즈 개수를 숨긴다")
    func displayedPoseCount_beforeFirstPageOfCondition_isNil() {
        var state = PoseFeature.State()
        state.loadedGeneralFilter = PoseListFilter()
        state.generalTotalCount = 51
        state.toggleRelationFilter(.friend)

        #expect(state.displayedPoseCount == nil)
    }

    @Test("지금 조건의 첫 페이지를 받았으면 서버가 알려 준 전체 개수를 보여 준다")
    func displayedPoseCount_afterFirstPage_isTotalCount() {
        var state = PoseFeature.State()
        state.loadedGeneralFilter = PoseListFilter()
        state.generalTotalCount = 51

        #expect(state.displayedPoseCount == 51)
    }

    @Test("북마크 목록에서는 북마크 전체 개수를 보여 준다")
    func displayedPoseCount_inBookmark_isScrappedTotalCount() {
        var state = PoseFeature.State()
        state.loadedGeneralFilter = PoseListFilter()
        state.generalTotalCount = 51
        state.scrappedTotalCount = 3
        state.toggleBookmarkFilter()

        #expect(state.displayedPoseCount == 3)
    }

    @Test("조건이 비어 있으면 모든 포즈가 맞고, 인원수와 관계를 고르면 둘 다 맞는 포즈만 맞다")
    func listFilter_matchesPeopleCountAndRelation() {
        let poses = [
            makePose(id: 1, peopleCount: .duo, relation: .friend),
            makePose(id: 2, peopleCount: .duo, relation: nil),
            makePose(id: 3, peopleCount: .solo, relation: nil)
        ]

        #expect(poses.filter(PoseListFilter().matches).map(\.id) == [1, 2, 3])
        #expect(poses.filter(PoseListFilter(peopleCount: .duo).matches).map(\.id) == [1, 2])
        #expect(poses.filter(PoseListFilter(peopleCount: .duo, relation: .friend).matches).map(\.id) == [1])
    }
}

private extension PoseFilterRuleTests {
    func makePose(id: PoseID, peopleCount: PeopleCountOption, relation: PoseRelation?) -> Pose {
        Pose(
            id: id,
            peopleCountOption: peopleCount,
            imageURL: nil,
            isScrapped: false,
            contentType: .jpeg,
            width: nil,
            height: nil,
            relation: relation
        )
    }
}
