require 'spec_helper'

describe Mongoid::Tree::Ordering do
  describe 'when saved' do
    before(:each) do
      setup_ordered_tree <<-ENDTREE
        - root:
          - child:
            - subchild:
              - subsubchild
        - other_root:
          - other_child
      ENDTREE
    end

    it "should assign a default position of 0 to each node without a sibling" do
      node(:child).position.should == 0
      node(:subchild).position.should == 0
      node(:subsubchild).position.should == 0
    end

    it "should place siblings at the end of the list by default" do
      node(:root).position.should == 0
      node(:other_root).position.should == 1
    end

    it "should move a node to the end of a list when it is moved to a new parent" do
      other_root = node(:other_root)
      child = node(:child)
      child.position.should == 0
      other_root.children << child
      child.reload
      child.position.should == 1
    end
  end

  describe 'destroy strategies' do
    before(:each) do
      setup_ordered_tree <<-ENDTREE
        - root:
           - child:
             - subchild
           - other_child
        - other_root
      ENDTREE
    end

    describe ':move_children_to_parent' do
      it "should set its childen's parent_id to the documents parent_id" do
        node(:child).move_children_to_parent
        node(:child).should be_leaf
        node(:root).children.to_a.should == [node(:child), node(:other_child), node(:subchild)]
      end
    end
  end

  describe 'utility methods' do
    before(:each) do
      setup_ordered_tree <<-ENDTREE
        - first_root:
           - first_child_of_first_root
           - second_child_of_first_root
        - second_root
        - third_root
      ENDTREE
    end

    describe '#lower_items' do
      it "should return a collection of items lower on the list" do
        node(:first_root).lower_items.to_a.should == [node(:second_root), node(:third_root)]
        node(:second_root).lower_items.to_a.should == [node(:third_root)]
        node(:third_root).lower_items.to_a.should == []
        node(:first_child_of_first_root).lower_items.to_a.should == [node(:second_child_of_first_root)]
        node(:second_child_of_first_root).lower_items.to_a.should == []
      end
    end

    describe '#higher_items' do
      it "should return a collection of items lower on the list" do
        node(:first_root).higher_items.to_a.should == []
        node(:second_root).higher_items.to_a.should == [node(:first_root)]
        node(:third_root).higher_items.to_a.should == [node(:first_root), node(:second_root)]
        node(:first_child_of_first_root).higher_items.to_a.should == []
        node(:second_child_of_first_root).higher_items.to_a.should == [node(:first_child_of_first_root)]
      end
    end

    describe '#at_top?' do
      it "should return true when the node is first in the list" do
        node(:first_root).at_top?.should == true
        node(:first_child_of_first_root).at_top?.should == true
      end
      
      it "should return false when the node is not first in the list" do
        node(:second_root).at_top?.should == false
        node(:third_root).at_top?.should == false
        node(:second_child_of_first_root).at_top?.should == false
      end
    end

    describe '#at_bottom?' do
      it "should return true when the node is last in the list" do
        node(:third_root).at_bottom?.should == true
        node(:second_child_of_first_root).at_bottom?.should == true
      end
      
      it "should return false when the node is not last in the list" do
        node(:first_root).at_bottom?.should == false
        node(:second_root).at_bottom?.should == false
        node(:first_child_of_first_root).at_bottom?.should == false
      end
    end
    
    describe '#last_item_in_list' do
      it "should return the last item in the list containing the current item" do
        node(:first_root).last_item_in_list.should == node(:third_root)
        node(:second_root).last_item_in_list.should == node(:third_root)
        node(:third_root).last_item_in_list.should == node(:third_root)
      end
    end

    describe '#first_item_in_list' do
      it "should return the first item in the list containing the current item" do
        node(:first_root).first_item_in_list.should == node(:first_root)
        node(:second_root).first_item_in_list.should == node(:first_root)
        node(:third_root).first_item_in_list.should == node(:first_root)
      end
    end
  end

  describe 'moving nodes around', :focus => true do
    before(:each) do
      setup_ordered_tree <<-ENDTREE
        - first_root:
           - first_child_of_first_root
           - second_child_of_first_root
        - second_root:
           - first_child_of_second_root
        - third_root
      ENDTREE
    end

    describe '#move_below' do
      it 'should fix positions within the current list when moving an item away from its current parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_below(node(:first_child_of_second_root))
        node(:second_child_of_first_root).position.should == 0
      end

      it 'should work when moving to a different parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_below(node(:first_child_of_second_root))
        node_to_move.reload
        node_to_move.at_bottom?.should == true
        node(:first_child_of_second_root).at_top?.should == true
      end

      it 'should be able to move the first node below the second node' do
        first_node = node(:first_root)
        second_node = node(:second_root)
        first_node.move_below(second_node)
        first_node.reload
        second_node.reload
        second_node.at_top?.should == true
        first_node.higher_items.to_a.should == [second_node]
      end
      
      it 'should be able to move the last node below the first node' do
        first_node = node(:first_root)
        last_node = node(:third_root)
        last_node.move_below(first_node)
        first_node.reload
        last_node.reload
        last_node.at_bottom?.should == false
        node(:second_root).at_bottom?.should == true
        last_node.higher_items.to_a.should == [first_node]
      end
    end

    describe '#move_above' do
      it 'should fix positions within the current list when moving an item away from its current parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_above(node(:first_child_of_second_root))
        node(:second_child_of_first_root).position.should == 0
      end

      it 'should work when moving to a different parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_above(node(:first_child_of_second_root))
        node_to_move.reload
        node_to_move.at_top?.should == true
        node(:first_child_of_second_root).at_bottom?.should == true
      end

      it 'should be able to move the last node above the second node' do
        last_node = node(:third_root)
        second_node = node(:second_root)
        last_node.move_above(second_node)
        last_node.reload
        second_node.reload
        second_node.at_bottom?.should == true
        last_node.higher_items.to_a.should == [node(:first_root)]
      end

      it 'should be able to move the first node above the last node' do
        first_node = node(:first_root)
        last_node = node(:third_root)
        first_node.move_above(last_node)
        first_node.reload
        last_node.reload
        node(:second_root).at_top?.should == true
        first_node.higher_items.to_a.should == [node(:second_root)]
      end
    end

    describe "#move_to_top" do
      it "should return true when attempting to move the first item" do
        node(:first_root).move_to_top.should == true
        node(:first_child_of_first_root).move_to_top.should == true
      end
      
      it "should be able to move the last item to the top" do
        first_node = node(:first_root)
        last_node = node(:third_root)
        last_node.move_to_top
        first_node.reload
        last_node.at_top?.should == true
        first_node.at_top?.should == false
        first_node.higher_items.to_a.should == [last_node]
        last_node.lower_items.to_a.should == [first_node, node(:second_root)]
      end
    end

    describe "#move_to_bottom" do
      it "should return true when attempting to move the last item" do
        node(:third_root).move_to_bottom.should == true
        node(:second_child_of_first_root).move_to_bottom.should == true
      end

      it "should be able to move the first item to the bottom" do
        first_node = node(:first_root)
        middle_node = node(:second_root)
        last_node = node(:third_root)
        first_node.move_to_bottom
        middle_node.reload
        last_node.reload
        first_node.at_top?.should == false
        first_node.at_bottom?.should == true
        last_node.at_bottom?.should == false
        last_node.at_top?.should == false
        middle_node.at_top?.should == true
        first_node.lower_items.to_a.should == []
        last_node.higher_items.to_a.should == [middle_node]
      end
    end
  end # moving nodes around
end # Mongoid::Tree::Ordering
